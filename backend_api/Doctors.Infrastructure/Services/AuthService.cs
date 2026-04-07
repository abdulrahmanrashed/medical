using System.Security.Cryptography;
using Doctors.Application.Common;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Auth;
using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Doctors.Infrastructure.Identity;
using Doctors.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly SignInManager<ApplicationUser> _signInManager;
    private readonly ApplicationDbContext _db;
    private readonly IJwtTokenGenerator _jwt;
    private readonly ICurrentUserService _currentUser;
    private readonly IPatientRepository _patients;
    private readonly IPasswordHasher<ApplicationUser> _passwordHasher;

    public AuthService(
        UserManager<ApplicationUser> userManager,
        SignInManager<ApplicationUser> signInManager,
        ApplicationDbContext db,
        IJwtTokenGenerator jwt,
        ICurrentUserService currentUser,
        IPatientRepository patients,
        IPasswordHasher<ApplicationUser> passwordHasher)
    {
        _userManager = userManager;
        _signInManager = signInManager;
        _db = db;
        _jwt = jwt;
        _currentUser = currentUser;
        _patients = patients;
        _passwordHasher = passwordHasher;
    }

    public async Task<AuthResponseDto> LoginAsync(LoginRequestDto request, CancellationToken cancellationToken = default)
    {
        if (!string.IsNullOrWhiteSpace(request.Phone))
        {
            var norm = PhoneNormalizer.Normalize(request.Phone);
            if (norm.Length == 0)
                throw new BadRequestAppException("Invalid phone or password.");

            var patient = await _patients.GetByNormalizedPhoneAsync(norm, cancellationToken)
                ?? throw new BadRequestAppException("Invalid phone or password.");
            if (patient.RegistrationStatus != PatientRegistrationStatus.Completed
                || string.IsNullOrEmpty(patient.PasswordHash))
                throw new BadRequestAppException("Invalid phone or password.");

            var verify = _passwordHasher.VerifyHashedPassword(
                new ApplicationUser(), patient.PasswordHash, request.Password);
            if (verify == PasswordVerificationResult.Failed)
                throw new BadRequestAppException("Invalid phone or password.");
            if (string.IsNullOrEmpty(patient.UserId))
                throw new BadRequestAppException("Patient account is incomplete.");

            var user = await _userManager.FindByIdAsync(patient.UserId)
                ?? throw new BadRequestAppException("Invalid phone or password.");
            await EnforceClinicNotSuspendedForStaffAsync(user, cancellationToken);
            return await BuildAuthResponseAsync(user, cancellationToken);
        }

        if (string.IsNullOrWhiteSpace(request.Email))
            throw new BadRequestAppException("Provide email (staff) or phone (patient).");

        var staffUser = await _userManager.FindByEmailAsync(request.Email);
        if (staffUser is null)
            throw new BadRequestAppException("Invalid email or password.");
        var valid = await _signInManager.CheckPasswordSignInAsync(staffUser, request.Password, lockoutOnFailure: false);
        if (!valid.Succeeded)
            throw new BadRequestAppException("Invalid email or password.");
        await EnforceClinicNotSuspendedForStaffAsync(staffUser, cancellationToken);
        return await BuildAuthResponseAsync(staffUser, cancellationToken);
    }

    private async Task EnforceClinicNotSuspendedForStaffAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        const string suspended =
            "Account Suspended. Please contact your clinic administrator regarding payment.";

        var roles = await _userManager.GetRolesAsync(user);

        if (roles.Contains(AppRoles.Doctor))
        {
            var doctor = await _db.Doctors.AsNoTracking()
                .Include(d => d.Clinic)
                .FirstOrDefaultAsync(d => d.UserId == user.Id, cancellationToken);
            if (doctor?.Clinic is { PaymentStatus: ClinicPaymentStatus.Unpaid })
                throw new ForbiddenException(suspended);
        }

        if (roles.Contains(AppRoles.Reception) && user.AssignedClinicId is int receptionClinicId)
        {
            var clinic = await _db.Clinics.AsNoTracking()
                .FirstOrDefaultAsync(c => c.Id == receptionClinicId, cancellationToken);
            if (clinic?.PaymentStatus == ClinicPaymentStatus.Unpaid)
                throw new ForbiddenException(suspended);
        }
    }

    /// <summary>
    /// Scenario B (app registration): same normalized phone must map to one row. Draft → complete in place (same Id).
    /// No row → new COMPLETED row. Already COMPLETED → reject (no duplicate accounts).
    /// Medical history stays on the patient row primary key; phone can change later via PATCH /api/patients/me without changing that id.
    /// </summary>
    public async Task<AuthResponseDto> RegisterPatientAsync(RegisterPatientRequestDto request, CancellationToken cancellationToken = default)
    {
        var norm = PhoneNormalizer.Normalize(request.Phone);
        if (norm.Length == 0)
            throw new BadRequestAppException("Phone is required.");

        var existing = await _patients.GetByNormalizedPhoneAsync(norm, cancellationToken);

        if (existing is { RegistrationStatus: PatientRegistrationStatus.Completed })
            throw new BadRequestAppException("An account with this phone already exists.");

        // Existing DRAFT (e.g. created by reception): same patient_id, update row to COMPLETED — never new Guid.
        if (existing is { RegistrationStatus: PatientRegistrationStatus.Draft })
        {
            if (await _userManager.FindByNameAsync(norm) is not null)
                throw new BadRequestAppException("This phone is already linked to an account.");

            var user = new ApplicationUser
            {
                UserName = norm,
                Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim(),
                EmailConfirmed = true
            };
            ApplyFullNameToUser(user, request.FullName);

            var create = await _userManager.CreateAsync(user, RandomInternalPassword());
            if (!create.Succeeded)
                throw new BadRequestAppException(string.Join("; ", create.Errors.Select(e => e.Description)));

            await _userManager.AddToRoleAsync(user, AppRoles.Patient);

            existing.FullName = request.FullName.Trim();
            existing.Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim();
            existing.DateOfBirth = request.DateOfBirth;
            existing.InsuranceStatus = request.InsuranceStatus;
            existing.InsuranceDetails = request.InsuranceDetails;
            existing.ChronicDiseases = request.ChronicDiseases;
            existing.PasswordHash = _passwordHasher.HashPassword(user, request.Password);
            existing.RegistrationStatus = PatientRegistrationStatus.Completed;
            existing.UserId = user.Id;
            existing.UpdatedAtUtc = DateTime.UtcNow;
            _patients.Update(existing);
            await _db.SaveChangesAsync(cancellationToken);

            return await BuildAuthResponseAsync(user, cancellationToken);
        }

        // No row for this phone: brand-new COMPLETED patient with new stable Id.
        {
            if (await _userManager.FindByNameAsync(norm) is not null)
                throw new BadRequestAppException("This phone is already linked to an account.");

            var user = new ApplicationUser
            {
                UserName = norm,
                Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim(),
                EmailConfirmed = true
            };
            ApplyFullNameToUser(user, request.FullName);

            var create = await _userManager.CreateAsync(user, RandomInternalPassword());
            if (!create.Succeeded)
                throw new BadRequestAppException(string.Join("; ", create.Errors.Select(e => e.Description)));

            await _userManager.AddToRoleAsync(user, AppRoles.Patient);

            var patient = new Patient
            {
                Id = Guid.NewGuid(),
                PhoneNumber = norm,
                FullName = request.FullName.Trim(),
                Email = string.IsNullOrWhiteSpace(request.Email) ? null : request.Email.Trim(),
                DateOfBirth = request.DateOfBirth,
                InsuranceStatus = request.InsuranceStatus,
                InsuranceDetails = request.InsuranceDetails,
                ChronicDiseases = request.ChronicDiseases,
                RegistrationStatus = PatientRegistrationStatus.Completed,
                UserId = user.Id,
                PasswordHash = _passwordHasher.HashPassword(user, request.Password),
                CreatedAtUtc = DateTime.UtcNow
            };
            await _patients.AddAsync(patient, cancellationToken);
            await _db.SaveChangesAsync(cancellationToken);

            return await BuildAuthResponseAsync(user, cancellationToken);
        }
    }

    public async Task<AuthResponseDto> RegisterDoctorAsync(RegisterDoctorRequestDto request, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.ClinicAdmin))
            throw new ForbiddenException("Only clinic administrators can register doctors.");

        var myClinic = _currentUser.GetAssignedClinicId()
            ?? throw new ForbiddenException("Clinic administrator is not assigned to a clinic.");
        if (myClinic != request.ClinicId)
            throw new ForbiddenException("You can only register doctors for your clinic.");

        var clinicExists = await _db.Clinics.AnyAsync(c => c.Id == request.ClinicId, cancellationToken);
        if (!clinicExists)
            throw new BadRequestAppException("Clinic was not found.");

        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            EmailConfirmed = true
        };
        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
            throw new BadRequestAppException(string.Join("; ", result.Errors.Select(e => e.Description)));
        await _userManager.AddToRoleAsync(user, AppRoles.Doctor);

        var doctor = new Doctor
        {
            UserId = user.Id,
            ClinicId = request.ClinicId,
            Specialization = request.Specialization,
            LicenseNumber = request.LicenseNumber,
            CreatedAtUtc = DateTime.UtcNow
        };
        _db.Doctors.Add(doctor);
        await _db.SaveChangesAsync(cancellationToken);

        return await BuildAuthResponseAsync(user, cancellationToken);
    }

    public async Task<AuthResponseDto> RegisterReceptionAsync(RegisterReceptionRequestDto request, CancellationToken cancellationToken = default)
    {
        if (!_currentUser.IsInRole(AppRoles.ClinicAdmin))
            throw new ForbiddenException("Only clinic administrators can register receptionists.");

        var myClinic = _currentUser.GetAssignedClinicId()
            ?? throw new ForbiddenException("Clinic administrator is not assigned to a clinic.");
        if (myClinic != request.ClinicId)
            throw new ForbiddenException("You can only register receptionists for your clinic.");

        var clinicExists = await _db.Clinics.AnyAsync(c => c.Id == request.ClinicId, cancellationToken);
        if (!clinicExists)
            throw new BadRequestAppException("Clinic was not found.");

        var user = new ApplicationUser
        {
            UserName = request.Email,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            AssignedClinicId = request.ClinicId,
            EmailConfirmed = true
        };
        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
            throw new BadRequestAppException(string.Join("; ", result.Errors.Select(e => e.Description)));
        await _userManager.AddToRoleAsync(user, AppRoles.Reception);

        return await BuildAuthResponseAsync(user, cancellationToken);
    }

    private async Task<AuthResponseDto> BuildAuthResponseAsync(ApplicationUser user, CancellationToken cancellationToken)
    {
        var roles = await _userManager.GetRolesAsync(user);
        var doctor = await _db.Doctors.AsNoTracking().FirstOrDefaultAsync(d => d.UserId == user.Id, cancellationToken);
        var patient = await _db.Patients.AsNoTracking().FirstOrDefaultAsync(p => p.UserId == user.Id, cancellationToken);
        var token = _jwt.CreateToken(
            user.Id,
            user.Email ?? string.Empty,
            roles,
            doctor?.Id,
            patient?.Id,
            user.AssignedClinicId);
        return new AuthResponseDto
        {
            Token = token,
            Email = user.Email ?? string.Empty,
            UserId = user.Id,
            Roles = roles.ToList(),
            DoctorId = doctor?.Id,
            PatientId = patient?.Id,
            AssignedClinicId = user.AssignedClinicId
        };
    }

    private static string RandomInternalPassword() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)) + "aA1!";

    private static void ApplyFullNameToUser(ApplicationUser user, string fullName)
    {
        var parts = fullName.Trim().Split(' ', 2, StringSplitOptions.RemoveEmptyEntries);
        user.FirstName = parts.Length > 0 ? parts[0] : fullName.Trim();
        user.LastName = parts.Length > 1 ? parts[1] : string.Empty;
    }
}
