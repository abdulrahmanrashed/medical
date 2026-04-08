using Doctors.Domain.Common;

namespace Doctors.Application.DTOs.Clinics;

public class ClinicDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public int DoctorCount { get; set; }
    public ClinicPaymentStatus PaymentStatus { get; set; }
    public DateTime? SubscriptionStartDate { get; set; }
    public DateTime? LastPaymentDate { get; set; }
    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal RemainingAmount { get; set; }
    public DateTime? SubscriptionEndDate { get; set; }

    /// <summary>Clinic owner (ClinicAdmin) full name from Identity.</summary>
    public string? OwnerFullName { get; set; }

    /// <summary>Clinic owner email (ClinicAdmin login).</summary>
    public string? OwnerEmail { get; set; }

    /// <summary>Days since <see cref="LastPaymentDate"/> or subscription/creation anchor (UTC).</summary>
    public int DaysSinceLastPaymentReference { get; set; }
    /// <summary>Use <see cref="ClinicSubscriptionUiStatus.UnpaidOverdue"/> in Flutter for a red subscription warning.</summary>
    public ClinicSubscriptionUiStatus SubscriptionStatus { get; set; }
}

public class CreateClinicDto
{
    public string Name { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }

    /// <summary>Clinic owner login (ClinicAdmin role).</summary>
    public string ClinicAdminEmail { get; set; } = string.Empty;

    public string ClinicAdminPassword { get; set; } = string.Empty;
    public string ClinicAdminFirstName { get; set; } = string.Empty;
    public string ClinicAdminLastName { get; set; } = string.Empty;

    public decimal TotalAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public DateTime? SubscriptionEndDate { get; set; }
}

public class SetClinicPaymentStatusDto
{
    public ClinicPaymentStatus PaymentStatus { get; set; }
}

public class UpdateClinicDto
{
    public string Name { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
}

public class RecordClinicPaymentDto
{
    public decimal AmountPaid { get; set; }

    /// <summary>When the payment was received. Defaults to UTC now if omitted.</summary>
    public DateTime? PaymentDate { get; set; }

    /// <summary>New subscription expiry after this payment.</summary>
    public DateTime NextExpiryDate { get; set; }
}

public class ClinicInvoiceDto
{
    /// <summary>Invoice / row identifier.</summary>
    public int InvoiceId { get; set; }
    public int ClinicId { get; set; }
    public decimal AmountPaid { get; set; }
    public DateTime PaymentDate { get; set; }
    public DateTime NextExpiryDate { get; set; }
}

/// <summary>All clinics&apos; invoices for admin billing history (includes clinic name).</summary>
public class ClinicInvoiceListItemDto
{
    public int InvoiceId { get; set; }
    public int ClinicId { get; set; }
    public string ClinicName { get; set; } = string.Empty;

    /// <summary>Amount recorded on this invoice row (single payment).</summary>
    public decimal AmountPaid { get; set; }

    /// <summary>Clinic contract total (current values from the clinic record).</summary>
    public decimal TotalAmount { get; set; }

    /// <summary>Cumulative paid on the clinic account (current).</summary>
    public decimal ClinicPaidAmount { get; set; }

    /// <summary>Outstanding balance on the clinic (current).</summary>
    public decimal RemainingAmount { get; set; }

    public DateTime PaymentDate { get; set; }
    public DateTime NextExpiryDate { get; set; }
}
