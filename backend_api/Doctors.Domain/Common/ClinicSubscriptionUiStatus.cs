namespace Doctors.Domain.Common;

/// <summary>
/// Drives subscription UI (e.g. Flutter: <see cref="UnpaidOverdue"/> → red).
/// </summary>
public enum ClinicSubscriptionUiStatus
{
    /// <summary>Subscription is within grace period, paid, or not requiring a red warning.</summary>
    Active = 0,

    /// <summary>Unpaid and more than 30 days since the last payment reference date.</summary>
    UnpaidOverdue = 1,

    /// <summary>Subscription period ended with an outstanding balance (staff access suspended).</summary>
    Frozen = 2
}
