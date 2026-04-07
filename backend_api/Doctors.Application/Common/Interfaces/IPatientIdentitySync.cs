namespace Doctors.Application.Common.Interfaces;

/// <summary>
/// Keeps ASP.NET Identity login identifiers aligned with <see cref="Domain.Entities.Patient"/> contact fields
/// so phone login continues to work after the patient changes phone in settings. The patient row primary key never changes.
/// </summary>
public interface IPatientIdentitySync
{
    Task UpdateLoginIdentifiersAsync(
        string identityUserId,
        string normalizedPhone,
        string? email,
        CancellationToken cancellationToken = default);
}
