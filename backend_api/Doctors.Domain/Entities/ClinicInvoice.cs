namespace Doctors.Domain.Entities;

/// <summary>Billing history for clinic subscription payments.</summary>
public class ClinicInvoice : BaseEntity
{
    public int ClinicId { get; set; }
    public Clinic Clinic { get; set; } = null!;

    public decimal AmountPaid { get; set; }

    /// <summary>When the payment was received (UTC).</summary>
    public DateTime PaymentDate { get; set; }

    /// <summary>Subscription end date after this payment (UTC).</summary>
    public DateTime NextExpiryDate { get; set; }
}
