using Doctors.Application.Common.Interfaces;

using Doctors.Infrastructure.Identity;

using Microsoft.AspNetCore.Identity;



namespace Doctors.Infrastructure.Services;



public class UserAccountDeletionService : IUserAccountDeletionService

{

    private readonly UserManager<ApplicationUser> _users;



    public UserAccountDeletionService(UserManager<ApplicationUser> users)

    {

        _users = users;

    }



    public async Task DeleteByUserIdAsync(string userId, CancellationToken cancellationToken = default)

    {

        var user = await _users.FindByIdAsync(userId);

        if (user is not null)

            await _users.DeleteAsync(user);

    }

}

