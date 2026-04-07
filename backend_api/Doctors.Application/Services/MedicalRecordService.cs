using AutoMapper;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.Configuration;
using Doctors.Application.DTOs.MedicalRecords;
using Doctors.Application.DTOs.Notifications;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Doctors.Application.Services;

public class MedicalRecordService : IMedicalRecordService
{
    private readonly IRepository<MedicalRecord> _records;
    private readonly IRepository<Prescription> _prescriptions;
    private readonly IRepository<Medication> _medications;
    private readonly IRepository<FileAttachment> _attachments;
    private readonly IPatientClinicLinkService _patientClinicLinks;
    private readonly IPatientRepository _patients;
    private readonly IRepository<Doctor> _doctors;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUserService _currentUser;
    private readonly IUserProfileReader _userProfileReader;
    private readonly INotificationService _notifications;
    private readonly IMapper _mapper;
    private readonly IOptions<AppUrlOptions> _appUrls;

    public MedicalRecordService(
        IRepository<MedicalRecord> records,
        IRepository<Prescription> prescriptions,
        IRepository<Medication> medications,
        IRepository<FileAttachment> attachments,
        IPatientClinicLinkService patientClinicLinks,
        IPatientRepository patients,
        IRepository<Doctor> doctors,
        IUnitOfWork unitOfWork,
        ICurrentUserService currentUser,
        IUserProfileReader userProfileReader,
        INotificationService notifications,
        IMapper mapper,
        IOptions<AppUrlOptions> appUrls)
    {
        _records = records;
        _prescriptions = prescriptions;
        _medications = medications;
        _attachments = attachments;
        _patientClinicLinks = patientClinicLinks;
        _patients = patients;
        _doctors = doctors;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _userProfileReader = userProfileReader;
        _notifications = notifications;
        _mapper = mapper;
        _appUrls = appUrls;
    }

    public async Task<IReadOnlyList<MedicalRecordDto>> GetForCurrentUserAsync(CancellationToken cancellationToken = default)
    {
        var query = _records.Query()
            .Include(r => r.Patient)
            .Include(r => r.Doctor)
            .Include(r => r.Prescriptions)
            .ThenInclude(p => p.Medications)
            .Include(r => r.Attachments)
            .AsQueryable();

        if (_currentUser.IsInRole(AppRoles.Admin))
        {
            // all
        }
        else if (_currentUser.IsInRole(AppRoles.Doctor))
        {
            var doctorId = _currentUser.GetDoctorId()
                ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
            var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
                ?? throw new NotFoundException("Doctor was not found.");
            query = query.Where(r => r.ClinicId == doctor.ClinicId);
        }
        else if (_currentUser.IsInRole(AppRoles.Patient))
        {
            var patientId = _currentUser.GetPatientId()
                ?? throw new ForbiddenException("Patient profile was not found for the current user.");
            query = query.Where(r => r.PatientId == patientId);
        }
        else
        {
            throw new ForbiddenException("You are not allowed to view medical records.");
        }

        var list = await query.OrderByDescending(r => r.CreatedAtUtc).ToListAsync(cancellationToken);
        var result = new List<MedicalRecordDto>();
        foreach (var r in list)
        {
            result.Add(await MapRecordAsync(r, cancellationToken));
        }
        return result;
    }

    public async Task<MedicalRecordDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var entity = await _records.Query()
            .Include(r => r.Patient)
            .Include(r => r.Doctor)
            .Include(r => r.Prescriptions)
            .ThenInclude(p => p.Medications)
            .Include(r => r.Attachments)
            .FirstOrDefaultAsync(r => r.Id == id, cancellationToken);
        if (entity is null)
            throw new NotFoundException($"Medical record {id} was not found.");
        await EnsureCanAccessAsync(entity, cancellationToken);
        return await MapRecordAsync(entity, cancellationToken);
    }

    public async Task<MedicalRecordDto> CreateAsync(CreateMedicalRecordDto dto, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can create medical records.");

        var doctorId = _currentUser.GetDoctorId()
            ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
        var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
            ?? throw new NotFoundException("Doctor was not found.");

        if (dto.ClinicId != doctor.ClinicId)
            throw new ForbiddenException("You can only create records for your clinic.");

        if (dto.DoctorId is int declaredDoctorId && declaredDoctorId != doctor.Id)
            throw new BadRequestAppException("doctorId in the request must match the signed-in doctor.");

        await _patientClinicLinks.EnsurePatientLinkedToClinicAsync(dto.PatientId, dto.ClinicId, cancellationToken);

        var record = new MedicalRecord
        {
            PatientId = dto.PatientId,
            DoctorId = doctor.Id,
            ClinicId = dto.ClinicId,
            Symptoms = dto.Symptoms,
            Diagnosis = dto.Diagnosis,
            Notes = dto.Notes,
            CreatedAtUtc = DateTime.UtcNow
        };
        await _records.AddAsync(record, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var prescription = new Prescription
        {
            MedicalRecordId = record.Id,
            DoctorId = doctor.Id,
            CreatedAtUtc = DateTime.UtcNow
        };
        await _prescriptions.AddAsync(prescription, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        if (dto.InitialMedications is { Count: > 0 })
        {
            foreach (var m in dto.InitialMedications)
            {
                await _medications.AddAsync(new Medication
                {
                    PrescriptionId = prescription.Id,
                    Name = m.Name,
                    Dosage = m.Dosage,
                    Schedule = m.Schedule,
                    Instructions = m.Instructions,
                    CreatedAtUtc = DateTime.UtcNow
                }, cancellationToken);
            }
            await _unitOfWork.SaveChangesAsync(cancellationToken);
        }

        var patient = await _patients.GetByIdAsync(dto.PatientId, cancellationToken)
            ?? throw new NotFoundException("Patient was not found.");
        if (!string.IsNullOrEmpty(patient.UserId))
        {
            await _notifications.NotifyAsync(new CreateNotificationDto
            {
                UserId = patient.UserId,
                Title = "New medical record",
                Message = "A doctor has added a new medical record to your profile.",
                Type = NotificationType.General,
                RelatedPrescriptionId = prescription.Id
            }, cancellationToken);
        }

        return await GetByIdAsync(record.Id, cancellationToken);
    }

    public async Task<MedicalRecordDto> UpdateAsync(int id, UpdateMedicalRecordDto dto, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can update medical records.");

        var doctorId = _currentUser.GetDoctorId()
            ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
        var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
            ?? throw new NotFoundException("Doctor was not found.");

        var record = await _records.Query()
            .FirstOrDefaultAsync(r => r.Id == id, cancellationToken);
        if (record is null)
            throw new NotFoundException($"Medical record {id} was not found.");
        if (record.DoctorId != doctor.Id)
            throw new ForbiddenException("You cannot modify this medical record.");

        record.Symptoms = dto.Symptoms;
        record.Diagnosis = dto.Diagnosis;
        record.Notes = dto.Notes;
        record.UpdatedAtUtc = DateTime.UtcNow;
        _records.Update(record);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(id, cancellationToken);
    }

    public async Task<MedicalRecordDto> AddMedicationAsync(AddMedicationDto dto, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can add medications.");

        var doctorId = _currentUser.GetDoctorId()
            ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
        var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
            ?? throw new NotFoundException("Doctor was not found.");

        var prescription = await _prescriptions.Query()
            .Include(p => p.MedicalRecord)
            .FirstOrDefaultAsync(p => p.Id == dto.PrescriptionId, cancellationToken);
        if (prescription is null)
            throw new NotFoundException($"Prescription {dto.PrescriptionId} was not found.");
        if (prescription.DoctorId != doctor.Id)
            throw new ForbiddenException("You cannot modify this prescription.");

        await _medications.AddAsync(new Medication
        {
            PrescriptionId = prescription.Id,
            Name = dto.Name,
            Dosage = dto.Dosage,
            Schedule = dto.Schedule,
            Instructions = dto.Instructions,
            CreatedAtUtc = DateTime.UtcNow
        }, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var userId = await _patients.Query()
            .Where(p => p.Id == prescription.MedicalRecord.PatientId)
            .Select(p => p.UserId)
            .FirstOrDefaultAsync(cancellationToken);
        if (!string.IsNullOrEmpty(userId))
        {
            await _notifications.NotifyAsync(new CreateNotificationDto
            {
                UserId = userId,
                Title = "Medication reminder",
                Message = $"Medication added: {dto.Name} — {dto.Dosage} ({dto.Schedule}).",
                Type = NotificationType.MedicationReminder,
                RelatedPrescriptionId = prescription.Id
            }, cancellationToken);
        }

        return await GetByIdAsync(prescription.MedicalRecordId, cancellationToken);
    }

    public async Task<MedicalRecordDto> RemoveMedicationAsync(int medicationId, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can remove medications.");

        var doctorId = _currentUser.GetDoctorId()
            ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
        var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
            ?? throw new NotFoundException("Doctor was not found.");

        var medication = await _medications.Query()
            .Include(m => m.Prescription)
            .FirstOrDefaultAsync(m => m.Id == medicationId, cancellationToken);
        if (medication is null)
            throw new NotFoundException($"Medication {medicationId} was not found.");
        if (medication.Prescription.DoctorId != doctor.Id)
            throw new ForbiddenException("You cannot modify this prescription.");

        var medicalRecordId = medication.Prescription.MedicalRecordId;
        _medications.Remove(medication);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        return await GetByIdAsync(medicalRecordId, cancellationToken);
    }

    public async Task<MedicalRecordDto> AddAttachmentAsync(
        int medicalRecordId,
        string relativePath,
        string originalFileName,
        string contentType,
        long sizeBytes,
        CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Doctor))
            throw new ForbiddenException("Only doctors can upload attachments.");

        var doctorId = _currentUser.GetDoctorId()
            ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
        var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
            ?? throw new NotFoundException("Doctor was not found.");

        var record = await _records.GetByIdAsync(medicalRecordId, cancellationToken);
        if (record is null)
            throw new NotFoundException($"Medical record {medicalRecordId} was not found.");
        if (record.DoctorId != doctor.Id)
            throw new ForbiddenException("You cannot modify this medical record.");

        var userId = _currentUser.UserId ?? throw new ForbiddenException("User is not authenticated.");
        await _attachments.AddAsync(new FileAttachment
        {
            MedicalRecordId = medicalRecordId,
            FilePath = relativePath,
            OriginalFileName = originalFileName,
            ContentType = contentType,
            FileSizeBytes = sizeBytes,
            UploadedByUserId = userId,
            CreatedAtUtc = DateTime.UtcNow
        }, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(medicalRecordId, cancellationToken);
    }

    private async Task EnsureCanAccessAsync(MedicalRecord entity, CancellationToken cancellationToken)
    {
        if (_currentUser.IsInRole(AppRoles.Admin))
            return;

        if (_currentUser.IsInRole(AppRoles.Doctor))
        {
            var doctorId = _currentUser.GetDoctorId()
                ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
            var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
                ?? throw new NotFoundException("Doctor was not found.");
            if (entity.ClinicId != doctor.ClinicId)
                throw new ForbiddenException("You cannot access this record.");
            return;
        }

        if (_currentUser.IsInRole(AppRoles.Patient))
        {
            var patientId = _currentUser.GetPatientId();
            if (patientId != entity.PatientId)
                throw new ForbiddenException("You cannot access this record.");
            return;
        }

        throw new ForbiddenException("You are not allowed to view medical records.");
    }

    private async Task<MedicalRecordDto> MapRecordAsync(MedicalRecord r, CancellationToken cancellationToken)
    {
        var dto = _mapper.Map<MedicalRecordDto>(r);
        foreach (var p in dto.Prescriptions)
        {
            p.PatientId = r.PatientId;
        }

        var profile = await _userProfileReader.GetAsync(r.Doctor.UserId, cancellationToken);
        dto.DoctorName = profile is null ? r.Doctor.UserId : $"{profile.FirstName} {profile.LastName}".Trim();
        ApplyAttachmentPublicUrls(dto);
        return dto;
    }

    private void ApplyAttachmentPublicUrls(MedicalRecordDto dto)
    {
        var origin = _appUrls.Value.PublicOrigin;
        if (string.IsNullOrWhiteSpace(origin))
            return;
        var baseUrl = origin.TrimEnd('/');
        foreach (var a in dto.Attachments)
        {
            var path = (a.FilePath ?? string.Empty).TrimStart('/');
            a.PublicUrl = string.IsNullOrEmpty(path) ? baseUrl : $"{baseUrl}/{path}";
        }
    }
}
