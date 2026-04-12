using AutoMapper;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.Configuration;
using Doctors.Application.DTOs.MedicalFiles;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Doctors.Application.Services;

public class MedicalFileService : IMedicalFileService
{
    private const long MaxBytes = 52_428_800;

    private readonly IRepository<MedicalFile> _files;
    private readonly IRepository<Appointment> _appointments;
    private readonly IRepository<Doctor> _doctors;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUserService _currentUser;
    private readonly IFileStorageService _storage;
    private readonly IMapper _mapper;
    private readonly IOptions<AppUrlOptions> _appUrls;

    public MedicalFileService(
        IRepository<MedicalFile> files,
        IRepository<Appointment> appointments,
        IRepository<Doctor> doctors,
        IUnitOfWork unitOfWork,
        ICurrentUserService currentUser,
        IFileStorageService storage,
        IMapper mapper,
        IOptions<AppUrlOptions> appUrls)
    {
        _files = files;
        _appointments = appointments;
        _doctors = doctors;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _storage = storage;
        _mapper = mapper;
        _appUrls = appUrls;
    }

    public async Task<MedicalFileDto> UploadForCurrentPatientAsync(
        int? appointmentId,
        Stream fileStream,
        string originalFileName,
        string contentType,
        long fileSizeBytes,
        CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Patient))
            throw new ForbiddenException("Only patients can upload medical files.");

        var patientId = _currentUser.GetPatientId()
            ?? throw new ForbiddenException("Patient profile was not found for the current user.");

        if (fileSizeBytes <= 0 || fileSizeBytes > MaxBytes)
            throw new BadRequestAppException("File must be non-empty and at most 50 MB.");

        var type = ResolveFileType(contentType, originalFileName);

        if (appointmentId is int aid)
        {
            var appt = await _appointments.Query()
                .FirstOrDefaultAsync(a => a.Id == aid, cancellationToken);
            if (appt is null)
                throw new NotFoundException($"Appointment {aid} was not found.");
            if (appt.PatientId != patientId)
                throw new ForbiddenException("You cannot attach files to another patient’s appointment.");
        }

        var relative = await _storage.SaveAsync(fileStream, originalFileName, contentType, cancellationToken);

        var entity = new MedicalFile
        {
            PatientId = patientId,
            AppointmentId = appointmentId,
            FileName = Path.GetFileName(originalFileName),
            FileUrl = relative,
            FileType = type,
            CreatedAtUtc = DateTime.UtcNow
        };
        await _files.AddAsync(entity, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        var dto = _mapper.Map<MedicalFileDto>(entity);
        ApplyPublicUrl(dto);
        return dto;
    }

    public async Task<IReadOnlyList<MedicalFileDto>> GetMineAsync(CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Patient))
            throw new ForbiddenException("Only patients can list their uploads.");

        var patientId = _currentUser.GetPatientId()
            ?? throw new ForbiddenException("Patient profile was not found for the current user.");

        var list = await _files.Query()
            .Where(f => f.PatientId == patientId)
            .OrderByDescending(f => f.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        return MapList(list);
    }

    public async Task<IReadOnlyList<MedicalFileDto>> GetForAppointmentAsync(
        int appointmentId,
        CancellationToken cancellationToken = default)
    {
        var appt = await _appointments.Query()
            .FirstOrDefaultAsync(a => a.Id == appointmentId, cancellationToken);
        if (appt is null)
            throw new NotFoundException($"Appointment {appointmentId} was not found.");

        await EnsureStaffCanAccessAppointmentAsync(appt, cancellationToken);

        var list = await _files.Query()
            .Where(f => f.PatientId == appt.PatientId && f.AppointmentId == appointmentId)
            .OrderByDescending(f => f.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        return MapList(list);
    }

    private async Task EnsureStaffCanAccessAppointmentAsync(Appointment appt, CancellationToken cancellationToken)
    {
        if (_currentUser.IsInRole(AppRoles.Admin))
            return;

        if (_currentUser.IsInRole(AppRoles.Reception))
        {
            var clinicId = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Reception user is not assigned to a clinic.");
            if (appt.ClinicId != clinicId)
                throw new ForbiddenException("You cannot access this appointment.");
            return;
        }

        if (_currentUser.IsInRole(AppRoles.Doctor))
        {
            var doctorId = _currentUser.GetDoctorId()
                ?? throw new ForbiddenException("Doctor profile was not found for the current user.");
            var doctor = await _doctors.GetByIdAsync(doctorId, cancellationToken)
                ?? throw new NotFoundException("Doctor was not found.");
            var pool = appt.Type == AppointmentType.General
                       || appt.Type == AppointmentType.PregnancyFollowUp
                       || appt.Type == AppointmentType.Diabetes;
            var ok = appt.ClinicId == doctor.ClinicId && (pool || appt.DoctorId == doctorId);
            if (!ok)
                throw new ForbiddenException("You cannot access this appointment.");
            return;
        }

        throw new ForbiddenException("You are not allowed to view appointment uploads.");
    }

    private IReadOnlyList<MedicalFileDto> MapList(List<MedicalFile> list)
    {
        var dtos = _mapper.Map<List<MedicalFileDto>>(list);
        foreach (var d in dtos)
            ApplyPublicUrl(d);
        return dtos;
    }

    private void ApplyPublicUrl(MedicalFileDto dto)
    {
        var origin = _appUrls.Value.PublicOrigin;
        if (string.IsNullOrWhiteSpace(origin))
            return;
        var baseUrl = origin.TrimEnd('/');
        var path = (dto.FileUrl ?? string.Empty).TrimStart('/');
        dto.PublicUrl = string.IsNullOrEmpty(path) ? baseUrl : $"{baseUrl}/{path}";
    }

    private static MedicalFileType ResolveFileType(string contentType, string fileName)
    {
        var ct = (contentType ?? string.Empty).ToLowerInvariant();
        var name = fileName ?? string.Empty;
        if (ct.Contains("pdf", StringComparison.OrdinalIgnoreCase) ||
            name.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
            return MedicalFileType.Pdf;
        if (ct.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            return MedicalFileType.Image;
        if (name.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ||
            name.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase) ||
            name.EndsWith(".jpeg", StringComparison.OrdinalIgnoreCase) ||
            name.EndsWith(".webp", StringComparison.OrdinalIgnoreCase) ||
            name.EndsWith(".gif", StringComparison.OrdinalIgnoreCase))
            return MedicalFileType.Image;
        return MedicalFileType.Image;
    }
}
