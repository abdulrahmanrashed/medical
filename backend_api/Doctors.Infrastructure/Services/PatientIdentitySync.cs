using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;

namespace Doctors.Infrastructure.Services;

public class PatientIdentitySync : IPatientIdentitySync
{
    private readonly UserManager<ApplicationUser> _userManager;

    public PatientIdentitySync(UserManager<ApplicationUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task UpdateLoginIdentifiersAsync(
        string identityUserId,
        string normalizedPhone,
        string? email,
        CancellationToken cancellationToken = default)
    {
        var user = await _userManager.FindByIdAsync(identityUserId);
        if (user is null)
            throw new NotFoundException("Identity user was not found for this patient.");

        var userNameResult = await _userManager.SetUserNameAsync(user, normalizedPhone);
        if (!userNameResult.Succeeded)
        {
            throw new BadRequestAppException(
                string.Join("; ", userNameResult.Errors.Select(e => e.Description)));
        }

        user.Email = string.IsNullOrWhiteSpace(email) ? null : email.Trim();
        var updateResult = await _userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            throw new BadRequestAppException(
                string.Join("; ", updateResult.Errors.Select(e => e.Description)));
        }
    }
}
