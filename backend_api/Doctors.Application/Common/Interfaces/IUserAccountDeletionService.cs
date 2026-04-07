namespace Doctors.Application.Common.Interfaces;



public interface IUserAccountDeletionService

{

    Task DeleteByUserIdAsync(string userId, CancellationToken cancellationToken = default);

}

