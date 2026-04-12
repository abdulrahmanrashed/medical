using AutoMapper;
using Doctors.Application.Common;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Patients;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class PatientService : IPatientService
{
    private readonly IPatientRepository _patients;
    private readonly IRepository<PatientClinic> _patientClinics;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUserService _currentUser;
    private readonly IPatientIdentitySync _patientIdentitySync;
    private readonly IMapper _mapper;

    public PatientService(
        IPatientRepository patients,
        IRepository<PatientClinic> patientClinics,
        IUnitOfWork unitOfWork,
        ICurrentUserService currentUser,
        IPatientIdentitySync patientIdentitySync,
        IMapper mapper)
    {
        _patients = patients;
        _patientClinics = patientClinics;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _patientIdentitySync = patientIdentitySync;
        _mapper = mapper;
    }

    public async Task<PatientDto> GetMyProfileAsync(CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId ?? throw new ForbiddenException("User is not authenticated.");
        var patient = await _patients.Query()
            .Include(p => p.PatientClinics)
            .FirstOrDefaultAsync(p => p.UserId == userId, cancellationToken);
        if (patient is null)
            throw new NotFoundException("Patient profile was not found for the current user.");
        return _mapper.Map<PatientDto>(patient);
    }

    public async Task<PatientDto> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var patient = await _patients.Query()
            .Include(p => p.PatientClinics)
            .FirstOrDefaultAsync(p => p.Id == id, cancellationToken);
        if (patient is null)
            throw new NotFoundException($"Patient {id} was not found.");
        return _mapper.Map<PatientDto>(patient);
    }

    public async Task<IReadOnlyList<PatientDto>> GetAllAsync(CancellationToken cancellationToken = default)
    {
        var list = await _patients.Query()
            .Include(p => p.PatientClinics)
            .OrderBy(p => p.FullName)
            .ToListAsync(cancellationToken);
        return _mapper.Map<IReadOnlyList<PatientDto>>(list);
    }

    public async Task<PatientDto> LinkToClinicAsync(LinkPatientClinicDto dto, CancellationToken cancellationToken = default)
    {
        if (_currentUser.IsInRole(AppRoles.Patient))
        {
            var mine = await _patients.Query().FirstOrDefaultAsync(p => p.UserId == _currentUser.UserId, cancellationToken);
            if (mine is null || mine.Id != dto.PatientId)
                throw new ForbiddenException("Patients can only link their own profile to a clinic.");
        }

        var exists = await _patientClinics.Query()
            .AnyAsync(pc => pc.PatientId == dto.PatientId && pc.ClinicId == dto.ClinicId, cancellationToken);
        if (exists)
            return await GetByIdAsync(dto.PatientId, cancellationToken);

        await _patientClinics.AddAsync(new PatientClinic
        {
            PatientId = dto.PatientId,
            ClinicId = dto.ClinicId,
            LinkedAtUtc = DateTime.UtcNow,
            CreatedAtUtc = DateTime.UtcNow
        }, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(dto.PatientId, cancellationToken);
    }

    public async Task<PatientDto> CreateDraftAsync(CreateDraftPatientDto dto, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Admin) && !_currentUser.IsInRole(AppRoles.Reception))
            throw new ForbiddenException("Only reception or admin can create draft patients.");

        var norm = PhoneNormalizer.Normalize(dto.Phone);
        if (norm.Length == 0)
            throw new BadRequestAppException("Phone is required.");

        var duplicate = await _patients.GetByNormalizedPhoneAsync(norm, cancellationToken);
        if (duplicate is not null)
            throw new BadRequestAppException("A patient with this phone already exists.");

        var entity = new Patient
        {
            Id = Guid.NewGuid(),
            PhoneNumber = norm,
            FullName = dto.FullName.Trim(),
            RegistrationStatus = PatientRegistrationStatus.Draft,
            CreatedAtUtc = DateTime.UtcNow
        };
        await _patients.AddAsync(entity, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return _mapper.Map<PatientDto>(entity);
    }

    public async Task<PatientDto> FindOrCreateDraftByPhoneAsync(
        ReceptionFindOrCreatePatientDto dto,
        CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Admin) && !_currentUser.IsInRole(AppRoles.Reception))
            throw new ForbiddenException("Only reception or admin can look up patients by phone.");

        var norm = PhoneNormalizer.Normalize(dto.Phone);
        if (norm.Length == 0)
            throw new BadRequestAppException("Phone is required.");

        var existing = await _patients.GetByNormalizedPhoneAsync(norm, cancellationToken);
        if (existing is not null)
            return await GetByIdAsync(existing.Id, cancellationToken);

        var name = dto.FullName.Trim();
        if (name.Length == 0)
            throw new BadRequestAppException("Full name is required when creating a new draft patient.");

        var entity = new Patient
        {
            Id = Guid.NewGuid(),
            PhoneNumber = norm,
            FullName = name,
            RegistrationStatus = PatientRegistrationStatus.Draft,
            CreatedAtUtc = DateTime.UtcNow
        };
        await _patients.AddAsync(entity, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return _mapper.Map<PatientDto>(entity);
    }

    public async Task<PatientDto?> LookupByPhoneForReceptionAsync(
        string phone,
        CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Admin) && !_currentUser.IsInRole(AppRoles.Reception))
            throw new ForbiddenException("Only reception or admin can look up patients by phone.");

        var norm = PhoneNormalizer.Normalize(phone);
        if (norm.Length == 0)
            return null;

        var existing = await _patients.GetByNormalizedPhoneAsync(norm, cancellationToken);
        if (existing is null)
            return null;

        return await GetByIdAsync(existing.Id, cancellationToken);
    }

    public async Task<PatientDto> UpdateMyProfileAsync(
        UpdatePatientProfileDto dto,
        CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.Patient))
            throw new ForbiddenException("Only patients can update this profile.");

        var myId = _currentUser.GetPatientId()
            ?? throw new ForbiddenException("Patient id was not found on the current principal.");

        var patient = await _patients.Query()
            .Include(p => p.PatientClinics)
            .FirstOrDefaultAsync(p => p.Id == myId, cancellationToken);
        if (patient is null)
            throw new NotFoundException("Patient profile was not found.");

        var phoneUpdated = false;
        if (dto.Phone is not null)
        {
            var norm = PhoneNormalizer.Normalize(dto.Phone);
            if (norm.Length == 0)
                throw new BadRequestAppException("Phone cannot be empty.");
            var other = await _patients.GetByNormalizedPhoneAsync(norm, cancellationToken);
            if (other is not null && other.Id != patient.Id)
                throw new BadRequestAppException("This phone number is already registered to another patient.");
            phoneUpdated = patient.PhoneNumber != norm;
            patient.PhoneNumber = norm;
        }

        if (dto.Email is not null)
            patient.Email = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim();

        if (dto.FullName is not null)
        {
            var n = dto.FullName.Trim();
            if (n.Length == 0)
                throw new BadRequestAppException("Full name cannot be empty.");
            patient.FullName = n;
        }

        if (dto.DateOfBirth.HasValue)
            patient.DateOfBirth = dto.DateOfBirth;

        if (dto.InsuranceStatus.HasValue)
            patient.InsuranceStatus = dto.InsuranceStatus.Value;

        if (dto.InsuranceDetails is not null)
            patient.InsuranceDetails = string.IsNullOrWhiteSpace(dto.InsuranceDetails) ? null : dto.InsuranceDetails.Trim();

        if (dto.ChronicDiseases is not null)
        {
            patient.ChronicDiseases = dto.ChronicDiseases
                .Select(x => x.Trim())
                .Where(x => x.Length > 0)
                .Take(50)
                .ToList();
            patient.HasChronicCondition = patient.ChronicDiseases.Count > 0;
        }

        patient.UpdatedAtUtc = DateTime.UtcNow;
        _patients.Update(patient);
        await _unitOfWork.SaveChangesAsync(cancellationToken);

        if (!string.IsNullOrEmpty(patient.UserId) && (phoneUpdated || dto.Email is not null))
        {
            await _patientIdentitySync.UpdateLoginIdentifiersAsync(
                patient.UserId,
                patient.PhoneNumber,
                patient.Email,
                cancellationToken);
        }

        return _mapper.Map<PatientDto>(patient);
    }

    public async Task<PatientRegistrationLookupResponseDto> LookupForAppRegistrationAsync(
        string phone,
        CancellationToken cancellationToken = default)
    {
        var norm = PhoneNormalizer.Normalize(phone);
        if (norm.Length == 0)
            return new PatientRegistrationLookupResponseDto { Found = false };

        var p = await _patients.GetByNormalizedPhoneAsync(norm, cancellationToken);
        if (p is null)
            return new PatientRegistrationLookupResponseDto { Found = false };

        if (p.RegistrationStatus == PatientRegistrationStatus.Completed)
        {
            return new PatientRegistrationLookupResponseDto
            {
                Found = true,
                RegistrationStatus = PatientRegistrationStatus.Completed
            };
        }

        return new PatientRegistrationLookupResponseDto
        {
            Found = true,
            RegistrationStatus = PatientRegistrationStatus.Draft,
            PatientId = p.Id,
            FullName = p.FullName,
            PhoneNumber = p.PhoneNumber,
            Email = p.Email,
            DateOfBirth = p.DateOfBirth,
            InsuranceStatus = p.InsuranceStatus,
            InsuranceDetails = p.InsuranceDetails,
            ChronicDiseases = p.ChronicDiseases.Count > 0 ? p.ChronicDiseases : null
        };
    }
}
