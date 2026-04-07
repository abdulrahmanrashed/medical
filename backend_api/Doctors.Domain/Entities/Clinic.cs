using Doctors.Domain.Common;

namespace Doctors.Domain.Entities;

public class Clinic : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }

    /// <summary>Identity user id of the clinic owner (ClinicAdmin role).</summary>
    public string? ClinicAdminUserId { get; set; }

    /// <summary>When Unpaid, doctor and reception accounts for this clinic are suspended.</summary>
    public ClinicPaymentStatus PaymentStatus { get; set; } = ClinicPaymentStatus.Unpaid;

    /// <summary>When the clinic&apos;s paid subscription period is considered to have started (UTC).</summary>
    public DateTime? SubscriptionStartDate { get; set; }

    /// <summary>Last recorded payment date (UTC). When null, <see cref="SubscriptionStartDate"/> or <see cref="BaseEntity.CreatedAtUtc"/> is used for grace calculations.</summary>
    public DateTime? LastPaymentDate { get; set; }

    /// <summary>Set when super admins were notified about unpaid overdue subscription; cleared when payment is recorded.</summary>
    public DateTime? SubscriptionOverdueNotifiedAtUtc { get; set; }

    public ICollection<Doctor> Doctors { get; set; } = new List<Doctor>();
    public ICollection<PatientClinic> PatientClinics { get; set; } = new List<PatientClinic>();

    /// <summary>
    /// Anchor date for &quot;days since last payment&quot;: last payment, else subscription start, else clinic creation.
    /// </summary>
    public DateTime GetLastPaymentReferenceUtc() =>
        LastPaymentDate ?? SubscriptionStartDate ?? CreatedAtUtc;

    /// <summary>Whole calendar days (UTC) from the payment reference date through <paramref name="asOfUtc"/>.</summary>
    public int GetDaysSinceLastPaymentReference(DateTime? asOfUtc = null)
    {
        var end = (asOfUtc ?? DateTime.UtcNow).Date;
        var start = GetLastPaymentReferenceUtc().Date;
        return (int)(end - start).TotalDays;
    }

    /// <summary>
    /// When unpaid and more than 30 days have passed since the payment reference date, returns
    /// <see cref="ClinicSubscriptionUiStatus.UnpaidOverdue"/> for client UI (e.g. red indicator).
    /// </summary>
    public ClinicSubscriptionUiStatus GetSubscriptionStatus(DateTime? asOfUtc = null)
    {
        if (PaymentStatus != ClinicPaymentStatus.Unpaid)
            return ClinicSubscriptionUiStatus.Active;
        return GetDaysSinceLastPaymentReference(asOfUtc) > 30
            ? ClinicSubscriptionUiStatus.UnpaidOverdue
            : ClinicSubscriptionUiStatus.Active;
    }
}
