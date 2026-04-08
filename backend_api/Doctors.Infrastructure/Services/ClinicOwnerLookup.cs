using Doctors.Application.Common.Interfaces;
using Doctors.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Services;

public class ClinicOwnerLookup : IClinicOwnerLookup
{
    private readonly UserManager<ApplicationUser> _userManager;

    public ClinicOwnerLookup(UserManager<ApplicationUser> userManager)
    {
        _userManager = userManager;
    }

    public async Task<IReadOnlyDictionary<string, ClinicOwnerSnapshot>> GetByUserIdsAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default)
    {
        if (userIds.Count == 0)
            return new Dictionary<string, ClinicOwnerSnapshot>();

        var idList = userIds.Where(id => !string.IsNullOrWhiteSpace(id)).Distinct().ToList();
        if (idList.Count == 0)
            return new Dictionary<string, ClinicOwnerSnapshot>();

        var users = await _userManager.Users
            .AsNoTracking()
            .Where(u => idList.Contains(u.Id))
            .ToListAsync(cancellationToken);

        return users.ToDictionary(
            u => u.Id,
            u => new ClinicOwnerSnapshot
            {
                FirstName = u.FirstName ?? string.Empty,
                LastName = u.LastName ?? string.Empty,
                Email = u.Email
            });
    }
}
