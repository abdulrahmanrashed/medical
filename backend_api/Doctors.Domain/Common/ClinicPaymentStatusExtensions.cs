namespace Doctors.Domain.Common;

public static class ClinicPaymentStatusExtensions
{
    /// <summary>Doctor and reception JWTs are blocked (same as legacy unpaid).</summary>
    public static bool SuspendsStaffAccess(this ClinicPaymentStatus status) =>
        status is ClinicPaymentStatus.Unpaid or ClinicPaymentStatus.Frozen;
}
