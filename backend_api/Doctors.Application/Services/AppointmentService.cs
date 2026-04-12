using AutoMapper;
using Doctors.Application.Common;
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
    private readonly IAppointmentRealtimeNotifier _realtime;
    private readonly IRepository<AppointmentPrescription> _appointmentPrescriptions;

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
        IPatientClinicLinkService patientClinicLinks,
        IAppointmentRealtimeNotifier realtime,
        IRepository<AppointmentPrescription> appointmentPrescriptions)
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
        _realtime = realtime;
        _appointmentPrescriptions = appointmentPrescriptions;
    }

    public async Task<PagedAppointmentsDto> GetPageForCurrentUserAsync(
        int? doctorId = null,
        int pageNumber = 1,
        int pageSize = 10,
        DateTime? scheduledFromUtc = null,
        DateTime? scheduledToUtc = null,
        CancellationToken cancellationToken = default)
    {
        pageNumber = Math.Max(1, pageNumber);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = await BuildFilteredQueryAsync(doctorId, cancellationToken);

        if (scheduledFromUtc is not null)
            query = query.Where(a => a.ScheduledAtUtc >= scheduledFromUtc.Value);
        if (scheduledToUtc is not null)
            query = query.Where(a => a.ScheduledAtUtc < scheduledToUtc.Value);

        // Order before count/page. Count runs without Includes (cheaper); only the page loads Clinic/Doctor.
        var ordered = query.OrderBy(a => a.ScheduledAtUtc);
        var totalCount = await ordered.CountAsync(cancellationToken);
        var page = await ordered
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .Include(a => a.AppointmentPrescriptions)
            .Skip((pageNumber - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var items = await MapListAsync(page, cancellationToken);
        return new PagedAppointmentsDto
        {
            Items = items,
            TotalCount = totalCount,
            PageNumber = pageNumber,
            PageSize = pageSize
        };
    }

    /// <summary>In-memory only; do not use inside EF-translated LINQ (not translatable to SQL).</summary>
    private static bool IsUnassignedPoolType(AppointmentType t) =>
        t == AppointmentType.General
        || t == AppointmentType.PregnancyFollowUp
        || t == AppointmentType.Diabetes;

    private async Task<IQueryable<Appointment>> BuildFilteredQueryAsync(int? doctorId, CancellationToken cancellationToken)
    {
        // No Include here — pagination applies Count/Skip/Take on a lean query; Includes added only when loading a page.
        var query = _appointments.Query().AsQueryable();

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
                (a.Type == AppointmentType.General
                    || a.Type == AppointmentType.PregnancyFollowUp
                    || a.Type == AppointmentType.Diabetes
                    || a.DoctorId == myDoctorId));
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
                (a.Type == AppointmentType.General
                    || a.Type == AppointmentType.PregnancyFollowUp
                    || a.Type == AppointmentType.Diabetes
                    || a.DoctorId == filterDoctorId));
        }

        return query;
    }

    public async Task<AppointmentDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .Include(a => a.AppointmentPrescriptions)
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
        if (IsUnassignedPoolType(dto.Type) && dto.DoctorId is not null)
            throw new BadRequestAppException("This appointment type must not pre-assign a doctor.");

        var specializedErr = AppointmentSpecializedDataValidator.ValidateOrNull(dto.Type, dto.SpecializedDataJson);
        if (specializedErr is not null)
            throw new BadRequestAppException(specializedErr);

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
            if (!doctor.IsActive)
                throw new BadRequestAppException("This doctor is currently unavailable for bookings.");
        }

        var status = isStaff ? AppointmentStatus.Approved : AppointmentStatus.Pending;
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
            DoctorNotes = dto.DoctorNotes,
            ReceptionNotes = dto.ReceptionNotes,
            SpecializedDataJson = string.IsNullOrWhiteSpace(dto.SpecializedDataJson)
                ? null
                : dto.SpecializedDataJson.Trim(),
            RequestedTests = string.IsNullOrWhiteSpace(dto.RequestedTests)
                ? null
                : dto.RequestedTests.Trim(),
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
            .Include(a => a.AppointmentPrescriptions)
            .FirstAsync(a => a.Id == entity.Id, cancellationToken);

        var result = await MapOneAsync(entity, cancellationToken);
        await _realtime.NotifyAppointmentUpsertAsync(await MapOneBroadcastAsync(entity, cancellationToken), cancellationToken);
        return result;
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
        if (IsUnassignedPoolType(dto.Type))
            dto.DoctorId = null;

        var specializedErrUp = AppointmentSpecializedDataValidator.ValidateOrNull(dto.Type, dto.SpecializedDataJson);
        if (specializedErrUp is not null)
            throw new BadRequestAppException(specializedErrUp);

        if (dto.DoctorId is int newDocId)
        {
            var forBooking = await _doctors.GetByIdAsync(newDocId, cancellationToken)
                ?? throw new NotFoundException($"Doctor {newDocId} was not found.");
            if (forBooking.ClinicId != entity.ClinicId)
                throw new BadRequestAppException("Doctor does not belong to this clinic.");
            if (!forBooking.IsActive)
                throw new BadRequestAppException("This doctor is currently unavailable for bookings.");
        }

        entity.DoctorId = dto.DoctorId;
        entity.PatientName = dto.PatientName;
        entity.PhoneNumber = dto.PhoneNumber;
        entity.ScheduledAtUtc = dto.ScheduledAtUtc;
        entity.Type = dto.Type;
        entity.Status = dto.Status;
        entity.Notes = dto.Notes;
        entity.DoctorNotes = dto.DoctorNotes;
        entity.ReceptionNotes = dto.ReceptionNotes;
        entity.SpecializedDataJson = string.IsNullOrWhiteSpace(dto.SpecializedDataJson)
            ? null
            : dto.SpecializedDataJson.Trim();
        entity.RequestedTests = string.IsNullOrWhiteSpace(dto.RequestedTests)
            ? null
            : dto.RequestedTests.Trim();
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

        entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .Include(a => a.AppointmentPrescriptions)
            .FirstAsync(a => a.Id == entity.Id, cancellationToken);

        var result = await MapOneAsync(entity, cancellationToken);
        await _realtime.NotifyAppointmentUpsertAsync(await MapOneBroadcastAsync(entity, cancellationToken), cancellationToken);
        return result;
    }

    public async Task<AppointmentDto> UpdateSessionByDoctorAsync(int id, DoctorUpdateAppointmentSessionDto dto, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can update session notes.");

        var entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
        if (entity is null)
            throw new NotFoundException($"Appointment {id} was not found.");

        await EnsureCanAccessAsync(entity, cancellationToken);

        if (dto.DoctorNotes is not null)
            entity.DoctorNotes = string.IsNullOrWhiteSpace(dto.DoctorNotes) ? null : dto.DoctorNotes.Trim();

        if (dto.SpecializedDataJson is not null)
        {
            var trimmed = dto.SpecializedDataJson.Trim();
            var jsonPayload = trimmed.Length == 0 ? null : trimmed;
            var err = AppointmentSpecializedDataValidator.ValidateOrNull(entity.Type, jsonPayload);
            if (err is not null)
                throw new BadRequestAppException(err);
            entity.SpecializedDataJson = jsonPayload;
        }

        if (dto.RequestedTests is not null)
        {
            entity.RequestedTests = string.IsNullOrWhiteSpace(dto.RequestedTests)
                ? null
                : dto.RequestedTests.Trim();
        }

        entity.UpdatedAtUtc = DateTime.UtcNow;
        _appointments.Update(entity);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .Include(a => a.AppointmentPrescriptions)
            .FirstAsync(a => a.Id == id, cancellationToken);

        var result = await MapOneAsync(entity, cancellationToken);
        await _realtime.NotifyAppointmentUpsertAsync(await MapOneBroadcastAsync(entity, cancellationToken), cancellationToken);
        return result;
    }

    public async Task<AppointmentDto> ReplaceAppointmentPrescriptionsAsync(
        int id,
        ReplaceAppointmentPrescriptionsDto dto,
        CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can update appointment prescriptions.");

        var entity = await _appointments.Query()
            .Include(a => a.AppointmentPrescriptions)
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
        if (entity is null)
            throw new NotFoundException($"Appointment {id} was not found.");

        await EnsureCanAccessAsync(entity, cancellationToken);

        foreach (var line in entity.AppointmentPrescriptions.ToList())
        {
            _appointmentPrescriptions.Remove(line);
        }

        foreach (var line in dto.Lines)
        {
            if (string.IsNullOrWhiteSpace(line.MedicationName))
                continue;

            var times = Math.Clamp(line.TimesPerDay, 1, 24);
            var start = line.StartDateUtc.Kind == DateTimeKind.Unspecified
                ? DateTime.SpecifyKind(line.StartDateUtc, DateTimeKind.Utc)
                : line.StartDateUtc.ToUniversalTime();
            DateTime? end = null;
            if (line.EndDateUtc is { } e)
            {
                end = e.Kind == DateTimeKind.Unspecified
                    ? DateTime.SpecifyKind(e, DateTimeKind.Utc)
                    : e.ToUniversalTime();
            }

            await _appointmentPrescriptions.AddAsync(new AppointmentPrescription
            {
                AppointmentId = id,
                MedicationName = line.MedicationName.Trim(),
                Dosage = string.IsNullOrWhiteSpace(line.Dosage) ? string.Empty : line.Dosage.Trim(),
                TimesPerDay = times,
                StartDateUtc = start,
                EndDateUtc = end,
                CreatedAtUtc = DateTime.UtcNow
            }, cancellationToken);
        }

        entity.UpdatedAtUtc = DateTime.UtcNow;
        _appointments.Update(entity);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .Include(a => a.AppointmentPrescriptions)
            .FirstAsync(a => a.Id == id, cancellationToken);

        var result = await MapOneAsync(entity, cancellationToken);
        await _realtime.NotifyAppointmentUpsertAsync(await MapOneBroadcastAsync(entity, cancellationToken), cancellationToken);
        return result;
    }

    public async Task<AppointmentDto> UpdateStatusByDoctorAsync(int id, AppointmentStatus newStatus, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can update session status.");

        var entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
        if (entity is null)
            throw new NotFoundException($"Appointment {id} was not found.");

        await EnsureCanAccessAsync(entity, cancellationToken);

        switch (newStatus)
        {
            case AppointmentStatus.InProgress:
                if (entity.Status is not (AppointmentStatus.Pending or AppointmentStatus.Approved))
                {
                    throw new BadRequestAppException(
                        "Only pending or approved appointments can be moved to in progress.");
                }
                break;
            case AppointmentStatus.Completed:
                if (entity.Status != AppointmentStatus.InProgress)
                {
                    throw new BadRequestAppException(
                        "Only an in-progress session can be completed. End the visit from the session screen.");
                }
                break;
            default:
                throw new BadRequestAppException("Doctors can only set status to InProgress or Completed.");
        }

        entity.Status = newStatus;
        entity.UpdatedAtUtc = DateTime.UtcNow;
        _appointments.Update(entity);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var patient = await _patients.GetByIdAsync(entity.PatientId, cancellationToken);
        if (!string.IsNullOrEmpty(patient?.UserId))
        {
            await _notifications.NotifyAsync(new CreateNotificationDto
            {
                UserId = patient!.UserId!,
                Title = "Appointment updated",
                Message = $"Your appointment status is now {entity.Status}.",
                Type = NotificationType.AppointmentUpdate,
                RelatedAppointmentId = entity.Id
            }, cancellationToken);
        }

        entity = await _appointments.Query()
            .Include(a => a.Clinic)
            .Include(a => a.Doctor)
            .Include(a => a.AppointmentPrescriptions)
            .FirstAsync(a => a.Id == id, cancellationToken);

        var result = await MapOneAsync(entity, cancellationToken);
        await _realtime.NotifyAppointmentUpsertAsync(await MapOneBroadcastAsync(entity, cancellationToken), cancellationToken);
        return result;
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

        var clinicIdBroadcast = entity.ClinicId;
        var patientIdBroadcast = entity.PatientId;
        var doctorIdBroadcast = entity.DoctorId;

        _appointments.Remove(entity);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        await _realtime.NotifyAppointmentDeletedAsync(id, clinicIdBroadcast, patientIdBroadcast, doctorIdBroadcast, cancellationToken);
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
                     (IsUnassignedPoolType(entity.Type) || entity.DoctorId == doctorId);
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
        return ApplyNoteVisibility(dto);
    }

    /// <summary>Full DTO for SignalR (all note fields); clients filter by role.</summary>
    private async Task<AppointmentDto> MapOneBroadcastAsync(Appointment a, CancellationToken cancellationToken)
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

    private AppointmentDto ApplyNoteVisibility(AppointmentDto dto)
    {
        if (_currentUser.IsInRole(AppRoles.Reception) || _currentUser.IsInRole(AppRoles.Admin))
            return dto;
        if (_currentUser.IsInRole(AppRoles.Doctor))
        {
            dto.ReceptionNotes = null;
            return dto;
        }
        dto.ReceptionNotes = null;
        dto.DoctorNotes = null;
        return dto;
    }
}
