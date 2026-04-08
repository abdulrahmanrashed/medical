namespace Doctors.Application.Common.Interfaces;

/// <summary>Resolves clinic owner (ClinicAdmin) display fields from Identity user ids.</summary>
public interface IClinicOwnerLookup
{
    Task<IReadOnlyDictionary<string, ClinicOwnerSnapshot>> GetByUserIdsAsync(
        IReadOnlyCollection<string> userIds,
        CancellationToken cancellationToken = default);
}

public sealed class ClinicOwnerSnapshot
{
    public string FirstName { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public string? Email { get; init; }
}
