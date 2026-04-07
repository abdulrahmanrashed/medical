namespace Doctors.Application.Common.Interfaces;

/// <summary>Notifies super administrators when a clinic is unpaid past the subscription grace period.</summary>
public interface ISubscriptionOverdueNotifier
{
    Task ProcessOverdueClinicsAsync(CancellationToken cancellationToken = default);
}
