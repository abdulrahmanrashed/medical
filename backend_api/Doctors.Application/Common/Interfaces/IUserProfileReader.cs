namespace Doctors.Application.Common.Interfaces;

public record UserProfileDto(string Email, string FirstName, string LastName);

public interface IUserProfileReader
{
    Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default);
}
