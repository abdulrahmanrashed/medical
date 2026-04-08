namespace Doctors.Domain.Common;



/// <summary>

/// Unpaid clinics cannot use Doctor or Reception staff accounts (login + API blocked).

/// ClinicAdmin may still sign in to manage payment contact with the system admin.

/// </summary>

public enum ClinicPaymentStatus
{
    Unpaid = 0,
    Paid = 1,

    /// <summary>Set automatically when <see cref="Entities.Clinic.SubscriptionEndDate"/> is past and <see cref="Entities.Clinic.RemainingAmount"/> is still owed.</summary>
    Frozen = 2
}

