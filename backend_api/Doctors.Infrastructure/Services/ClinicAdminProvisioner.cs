using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Domain.Common;
using Doctors.Infrastructure.Identity;
using Doctors.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Services;

public class ClinicAdminProvisioner : IClinicAdminProvisioner
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;

    public ClinicAdminProvisioner(ApplicationDbContext db, UserManager<ApplicationUser> userManager)
    {
        _db = db;
        _userManager = userManager;
    }

    public async Task<string> CreateAndLinkClinicAdminAsync(
        int clinicId,
        string email,
        string password,
        string firstName,
        string lastName,
        CancellationToken cancellationToken = default)
    {
        var clinic = await _db.Clinics.FirstOrDefaultAsync(c => c.Id == clinicId, cancellationToken);
        if (clinic is null)
            throw new NotFoundException($"Clinic {clinicId} was not found.");

        if (await _userManager.FindByEmailAsync(email) is not null)
            throw new BadRequestAppException("A user with this email already exists.");

        var user = new ApplicationUser
        {
            UserName = email,
            Email = email,
            FirstName = firstName,
            LastName = lastName,
            AssignedClinicId = clinicId,
            EmailConfirmed = true
        };

        var result = await _userManager.CreateAsync(user, password);
        if (!result.Succeeded)
            throw new BadRequestAppException(string.Join("; ", result.Errors.Select(e => e.Description)));

        await _userManager.AddToRoleAsync(user, AppRoles.ClinicAdmin);

        clinic.ClinicAdminUserId = user.Id;
        await _db.SaveChangesAsync(cancellationToken);

        return user.Id;
    }
}
