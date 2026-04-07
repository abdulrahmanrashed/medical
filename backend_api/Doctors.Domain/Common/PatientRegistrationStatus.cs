namespace Doctors.Domain.Common;

/// <summary>
/// Persisted as <c>DRAFT</c> or <c>COMPLETED</c> in the database.
/// </summary>
public enum PatientRegistrationStatus
{
    Draft,
    Completed
}

public static class PatientRegistrationStatusExtensions
{
    public static string ToStoredValue(this PatientRegistrationStatus status) =>
        status == PatientRegistrationStatus.Draft ? "DRAFT" : "COMPLETED";
}
