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
