namespace Doctors.Application.Common.Interfaces;

/// <summary>Sets <see cref="Domain.Common.ClinicPaymentStatus.Frozen"/> when subscription has ended and balance remains.</summary>
public interface IClinicSubscriptionFreezeService
{
    Task ApplyAutoFreezeAsync(CancellationToken cancellationToken = default);
}
