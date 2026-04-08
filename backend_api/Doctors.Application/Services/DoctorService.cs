using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Doctors;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class DoctorService : IDoctorService
{
    private readonly IRepository<Doctor> _doctors;
    private readonly IUserProfileReader _users;
    private readonly ICurrentUserService _currentUser;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IUserAccountDeletionService _userDeletion;

    public DoctorService(
        IRepository<Doctor> doctors,
        IUserProfileReader users,
        ICurrentUserService currentUser,
        IUnitOfWork unitOfWork,
        IUserAccountDeletionService userDeletion)
    {
        _doctors = doctors;
        _users = users;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
        _userDeletion = userDeletion;
    }

    public async Task<IReadOnlyList<DoctorDto>> GetByClinicAsync(int clinicId, CancellationToken cancellationToken = default)
    {
        if (_currentUser.IsInRole(AppRoles.ClinicAdmin))
        {
            var assigned = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Clinic administrator is not assigned to a clinic.");
            if (assigned != clinicId)
                throw new ForbiddenException("You can only list doctors for your own clinic.");
        }

        var query = _doctors.Query()
            .Include(d => d.Clinic)
            .Where(d => d.ClinicId == clinicId);

        if (_currentUser.IsInRole(AppRoles.Patient))
            query = query.Where(d => d.IsActive);

        var list = await query
            .OrderBy(d => d.Specialization)
            .ToListAsync(cancellationToken);
        var result = new List<DoctorDto>();
        foreach (var d in list)
        {
            result.Add(await MapDoctorAsync(d, cancellationToken));
        }
        return result;
    }

    public async Task<DoctorDto> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var doctor = await _doctors.Query()
            .Include(d => d.Clinic)
            .FirstOrDefaultAsync(d => d.Id == id, cancellationToken);
        if (doctor is null)
            throw new NotFoundException($"Doctor {id} was not found.");

        if (_currentUser.IsInRole(AppRoles.ClinicAdmin))
        {
            var assigned = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Clinic administrator is not assigned to a clinic.");
            if (assigned != doctor.ClinicId)
                throw new ForbiddenException("You cannot view doctors outside your clinic.");
        }

        if (_currentUser.IsInRole(AppRoles.Patient) && !doctor.IsActive)
            throw new NotFoundException($"Doctor {id} was not found.");

        return await MapDoctorAsync(doctor, cancellationToken);
    }

    public async Task<DoctorDto?> GetMineAsync(CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId;
        if (string.IsNullOrEmpty(userId))
            return null;
        var doctor = await _doctors.Query()
            .Include(d => d.Clinic)
            .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);
        if (doctor is null)
            return null;
        return await MapDoctorAsync(doctor, cancellationToken);
    }

    public async Task DeleteAsync(int id, CancellationToken cancellationToken = default)
    {
        var doctor = await _doctors.Query()
            .Include(d => d.Appointments)
            .Include(d => d.MedicalRecords)
            .Include(d => d.Prescriptions)
            .FirstOrDefaultAsync(d => d.Id == id, cancellationToken);
        if (doctor is null)
            throw new NotFoundException($"Doctor {id} was not found.");

        if (_currentUser.IsInRole(AppRoles.Admin))
        {
            // allowed
        }
        else if (_currentUser.IsInRole(AppRoles.ClinicAdmin))
        {
            var clinicId = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Clinic administrator is not assigned to a clinic.");
            if (clinicId != doctor.ClinicId)
                throw new ForbiddenException("You cannot remove doctors outside your clinic.");
        }
        else
        {
            throw new ForbiddenException("Only system admin or clinic administrators can remove doctors.");
        }

        if (doctor.Appointments.Count > 0 || doctor.MedicalRecords.Count > 0 || doctor.Prescriptions.Count > 0)
        {
            throw new BadRequestAppException(
                "Cannot delete a doctor who has appointments, medical records, or prescriptions.");
        }

        var userId = doctor.UserId;
        _doctors.Remove(doctor);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        await _userDeletion.DeleteByUserIdAsync(userId, cancellationToken);
    }

    private async Task<DoctorDto> MapDoctorAsync(Doctor doctor, CancellationToken cancellationToken)
    {
        var profile = await _users.GetAsync(doctor.UserId, cancellationToken);
        return new DoctorDto
        {
            Id = doctor.Id,
            UserId = doctor.UserId,
            Email = profile?.Email ?? string.Empty,
            FirstName = profile?.FirstName ?? string.Empty,
            LastName = profile?.LastName ?? string.Empty,
            ClinicId = doctor.ClinicId,
            ClinicName = doctor.Clinic.Name,
            Specialization = doctor.Specialization,
            LicenseNumber = doctor.LicenseNumber,
            PhoneNumber = doctor.PhoneNumber,
            YearsOfExperience = doctor.YearsOfExperience,
            Gender = doctor.Gender,
            IsActive = doctor.IsActive
        };
    }

    public async Task<DoctorDto> SetActiveAsync(int id, bool isActive, CancellationToken cancellationToken = default)
    {
        var doctor = await _doctors.Query()
            .Include(d => d.Clinic)
            .FirstOrDefaultAsync(d => d.Id == id, cancellationToken);
        if (doctor is null)
            throw new NotFoundException($"Doctor {id} was not found.");

        if (_currentUser.IsInRole(AppRoles.Admin))
        {
            // allowed
        }
        else if (_currentUser.IsInRole(AppRoles.ClinicAdmin))
        {
            var assigned = _currentUser.GetAssignedClinicId()
                ?? throw new ForbiddenException("Clinic administrator is not assigned to a clinic.");
            if (assigned != doctor.ClinicId)
                throw new ForbiddenException("You cannot change doctors outside your clinic.");
        }
        else
        {
            throw new ForbiddenException("Only system admin or clinic administrators can freeze or unfreeze doctors.");
        }

        doctor.IsActive = isActive;
        doctor.UpdatedAtUtc = DateTime.UtcNow;
        _doctors.Update(doctor);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        return await MapDoctorAsync(doctor, cancellationToken);
    }
}
