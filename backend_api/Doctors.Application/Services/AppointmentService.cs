using AutoMapper;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Appointments;
using Doctors.Application.DTOs.Notifications;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class AppointmentService : IAppointmentService
{
    private readonly IRepository<Appointment> _appointments;
    private readonly IPatientRepository _patients;
    private readonly IRepository<Doctor> _doctors;
    private readonly IRepository<Clinic> _clinics;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUserService _currentUser;
    private readonly IUserProfileReader _userProfileReader;
    private readonly INotificationService _notifications;
    private readonly IMapper _mapper;
    private readonly IPatientClinicLinkService _patientClinicLinks;

    public AppointmentService(
        IRepository<Appointment> appointments,
        IPatientRepository patients,
        IRepository<Doctor> doctors,
        IRepository<Clinic> clinics,
        IUnitOfWork unitOfWork,
        ICurrentUserService currentUser,
        IUserProfileReader userProfileReader,
        INotificationService notifications,
        IMapper mapper,
        IPatientClinicLinkService patientClinicLinks)
    {
        _appointments = appointments;
        _patients = patients;
        _doctors = doctors;
        _clinics = clinics;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _userProfileReader = userProfileReader;
        _notifications = notifications;
        _mapper = mapper;
        _patientClinicLinks = patientClinicLinks;
    }

    public async Task<IReadOnlyList<AppointmentDto>> GetAllForCurrentUserAsync(int? doctorId = null, CancellationToken cancellationToken = default)
    {
        var query = _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .AsQueryable();

        if (_currentUser.IsInRole(AppRoles.Admin))
        {
            // all clinics unless narrowed by doctorId
        }
        else if (_currentUser.IsInRole(AppRoles.Reception))
        {
            var clinicId = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Reception user is not assigned to a clinic.");
            query = query.Where(a => a.ClinicId == clinicId);
        }
        else if (_currentUser.IsInRole(AppRoles.Doctor))
        {
            var myDoctorId = _currentUser.GetDoctorId()
                ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
            var doctor = await _doctors.GetByIdAsync(myDoctorId, cancellationToken)
                ?? throw new NotFoundException("Doctor was not found.");
            if (doctorId is int requested && requested != myDoctorId)
                throw new ForbiddenException("You can only list appointments for your own doctor id.");
            query = query.Where(a =>
                a.ClinicId == doctor.ClinicId &&
                (a.Type == AppointmentType.General || a.DoctorId == myDoctorId));
        }
        else if (_currentUser.IsInRole(AppRoles.Patient))
        {
            var patientId = _currentUser.GetPatientId()
                ?? throw new ForbiddenException("Patient profile was not found for the current user.");
            query = query.Where(a => a.PatientId == patientId);
        }
        else
        {
            throw new ForbiddenException("You are not allowed to view appointments.");
        }

        if (doctorId is int filterDoctorId && !_currentUser.IsInRole(AppRoles.Patient))
        {
            var filterDoctor = await _doctors.GetByIdAsync(filterDoctorId, cancellationToken)
                ?? throw new NotFoundException($"Doctor {filterDoctorId} was not found.");

            if (_currentUser.IsInRole(AppRoles.Reception))
            {
                var clinicId = _currentUser.GetAssignedClinicId()
                    ?? throw new ForbiddenException("Reception user is not assigned to a clinic.");
                if (filterDoctor.ClinicId != clinicId)
                    throw new ForbiddenException("That doctor is not in your clinic.");
            }

            query = query.Where(a =>
                a.ClinicId == filterDoctor.ClinicId &&
                (a.Type == AppointmentType.General || a.DoctorId == filterDoctorId));
        }

        var list = await query.OrderBy(a => a.ScheduledAtUtc).ToListAsync(cancellationToken);
        return await MapListAsync(list, cancellationToken);
    }

    public async Task<AppointmentDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
        if (entity is null)
            throw new NotFoundException($"Appointment {id} was not found.");
        await EnsureCanAccessAsync(entity, cancellationToken);
        return await MapOneAsync(entity, cancellationToken);
    }

    public async Task<AppointmentDto> CreateAsync(CreateAppointmentDto dto, CancellationToken cancellationToken = default)
    {
        if (dto.Type == AppointmentType.SpecificDoctor && dto.DoctorId is null)
            throw new BadRequestAppException("Doctor is required for a specific-doctor appointment.");
        if (dto.Type == AppointmentType.General && dto.DoctorId is not null)
            throw new BadRequestAppException("General appointments must not assign a doctor.");

        var patient = await _patients.GetByIdAsync(dto.PatientId, cancellationToken)
            ?? throw new NotFoundException($"Patient {dto.PatientId} was not found.");

        var isPatient = _currentUser.IsInRole(AppRoles.Patient);
        var isStaff = _currentUser.IsInRole(AppRoles.Admin) || _currentUser.IsInRole(AppRoles.Reception);

        if (isPatient)
        {
            var myId = _currentUser.GetPatientId();
            if (myId != dto.PatientId)
                throw new ForbiddenException("Patients can only book appointments for themselves.");
        }
        else if (!isStaff)
        {
            throw new ForbiddenException("Only patients or staff can create appointments.");
        }

        if (dto.DoctorId is int docId)
        {
            var doctor = await _doctors.GetByIdAsync(docId, cancellationToken)
                ?? throw new NotFoundException($"Doctor {docId} was not found.");
            if (doctor.ClinicId != dto.ClinicId)
                throw new BadRequestAppException("Doctor does not belong to the selected clinic.");
        }

        var status = isStaff ? AppointmentStatus.Approved : AppointmentStatus.Pending;
        // Appointments always reference Patients.Id (stable UUID / patient_id); list for patients filters on this FK.
        var entity = new Appointment
        {
            PatientId = dto.PatientId,
            ClinicId = dto.ClinicId,
            DoctorId = dto.DoctorId,
            PatientName = dto.PatientName,
            PhoneNumber = dto.PhoneNumber,
            ScheduledAtUtc = dto.ScheduledAtUtc,
            Type = dto.Type,
            Status = status,
            Notes = dto.Notes,
            CreatedAtUtc = DateTime.UtcNow
        };
        await _appointments.AddAsync(entity, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        await _patientClinicLinks.EnsurePatientLinkedToClinicAsync(dto.PatientId, dto.ClinicId, cancellationToken);

        if (!string.IsNullOrEmpty(patient.UserId))
        {
            var clinic = await _clinics.GetByIdAsync(dto.ClinicId, cancellationToken);
            var clinicName = clinic?.Name ?? $"clinic #{dto.ClinicId}";
            await _notifications.NotifyAsync(new CreateNotificationDto
            {
                UserId = patient.UserId,
                Title = "Booking confirmation",
                Message = $"Your appointment at {clinicName} on {entity.ScheduledAtUtc:u} is {status}.",
                Type = NotificationType.BookingConfirmation,
                RelatedAppointmentId = entity.Id
            }, cancellationToken);
        }

        entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .FirstAsync(a => a.Id == entity.Id, cancellationToken);
        return await MapOneAsync(entity, cancellationToken);
    }

    public async Task<AppointmentDto> UpdateAsync(int id, UpdateAppointmentDto dto, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Admin) && !_currentUser.IsInRole(AppRoles.Reception))
            throw new ForbiddenException("Only reception or admin can update appointments.");

        var entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
        if (entity is null)
            throw new NotFoundException($"Appointment {id} was not found.");

        if (_currentUser.IsInRole(AppRoles.Reception))
        {
            var clinicId = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Reception user is not assigned to a clinic.");
            if (entity.ClinicId != clinicId)
                throw new ForbiddenException("You cannot modify appointments outside your clinic.");
        }

        if (dto.Type == AppointmentType.SpecificDoctor && dto.DoctorId is null)
            throw new BadRequestAppException("Doctor is required for a specific-doctor appointment.");
        if (dto.Type == AppointmentType.General)
            dto.DoctorId = null;

        entity.DoctorId = dto.DoctorId;
        entity.PatientName = dto.PatientName;
        entity.PhoneNumber = dto.PhoneNumber;
        // Apply scheduled time before status so confirmation persists the slot from this request.
        entity.ScheduledAtUtc = dto.ScheduledAtUtc;
        entity.Type = dto.Type;
        entity.Status = dto.Status;
        entity.Notes = dto.Notes;
        entity.UpdatedAtUtc = DateTime.UtcNow;
        _appointments.Update(entity);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var patient = await _patients.GetByIdAsync(entity.PatientId, cancellationToken);
        if (!string.IsNullOrEmpty(patient?.UserId))
        {
            await _notifications.NotifyAsync(new CreateNotificationDto
            {
                UserId = patient.UserId,
                Title = "Appointment updated",
                Message = $"Your appointment status is now {entity.Status}.",
                Type = NotificationType.AppointmentUpdate,
                RelatedAppointmentId = entity.Id
            }, cancellationToken);
        }

        return await MapOneAsync(entity, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Admin) && !_currentUser.IsInRole(AppRoles.Reception))
            throw new ForbiddenException("Only reception or admin can delete appointments.");

        var entity = await _appointments.GetByIdAsync(id, cancellationToken);
        if (entity is null)
            throw new NotFoundException($"Appointment {id} was not found.");

        if (_currentUser.IsInRole(AppRoles.Reception))
        {
            var clinicId = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Reception user is not assigned to a clinic.");
            if (entity.ClinicId != clinicId)
                throw new ForbiddenException("You cannot delete appointments outside your clinic.");
        }

        _appointments.Remove(entity);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    private async Task EnsureCanAccessAsync(Appointment entity, CancellationToken cancellationToken)
    {
        if (_currentUser.IsInRole(AppRoles.Admin))
            return;

        if (_currentUser.IsInRole(AppRoles.Reception))
        {
            var clinicId = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Reception user is not assigned to a clinic.");
            if (entity.ClinicId != clinicId)
                throw new ForbiddenException("You cannot access this appointment.");
            return;
        }

        if (_currentUser.IsInRole(AppRoles.Doctor))
        {
            var doctorId = _currentUser.GetDoctorId()
                ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
            var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
                ?? throw new NotFoundException("Doctor was not found.");
            var ok = entity.ClinicId == doctor.ClinicId &&
                     (entity.Type == AppointmentType.General || entity.DoctorId == doctorId);
            if (!ok)
                throw new ForbiddenException("You cannot access this appointment.");
            return;
        }

        if (_currentUser.IsInRole(AppRoles.Patient))
        {
            var patientId = _currentUser.GetPatientId();
            if (patientId != entity.PatientId)
                throw new ForbiddenException("You cannot access this appointment.");
            return;
        }

        throw new ForbiddenException("You are not allowed to view appointments.");
    }

    private async Task<IReadOnlyList<AppointmentDto>> MapListAsync(List<Appointment> list, CancellationToken cancellationToken)
    {
        var result = new List<AppointmentDto>();
        foreach (var a in list)
        {
            result.Add(await MapOneAsync(a, cancellationToken));
        }
        return result;
    }

    private async Task<AppointmentDto> MapOneAsync(Appointment a, CancellationToken cancellationToken)
    {
        var dto = _mapper.Map<AppointmentDto>(a);
        if (a.Doctor is not null)
        {
            var profile = await _userProfileReader.GetAsync(a.Doctor.UserId, cancellationToken);
            dto.DoctorName = profile is null
                ? a.Doctor.UserId
                : $"{profile.FirstName} {profile.LastName}".Trim();
        }
        return dto;
    }
}
