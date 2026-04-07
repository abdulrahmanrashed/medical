namespace Doctors.Application.Common.Interfaces;

/// <summary>Ensures a patient–clinic registration row exists (e.g. after first appointment or when opening a chart).</summary>
public interface IPatientClinicLinkService
{
    Task EnsurePatientLinkedToClinicAsync(Guid patientId, int clinicId, CancellationToken cancellationToken = default);
}
