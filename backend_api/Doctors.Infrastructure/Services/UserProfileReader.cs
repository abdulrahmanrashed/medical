using Doctors.Application.Common.Interfaces;
using Doctors.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Services;

public class UserProfileReader : IUserProfileReader
{
    private readonly UserManager<ApplicationUser> _users;

    public UserProfileReader(UserManager<ApplicationUser> users)
    {
        _users = users;
    }

    public async Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
    {
        var user = await _users.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is null)
            return null;
        return new UserProfileDto(user.Email ?? string.Empty, user.FirstName, user.LastName);
    }
}
