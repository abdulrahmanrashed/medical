using Doctors.Application.Common.Interfaces;

namespace Doctors.API.Services;

/// <summary>Periodically notifies super admins about clinics that are unpaid past the 30-day grace period.</summary>
public class SubscriptionOverdueBackgroundService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SubscriptionOverdueBackgroundService> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromHours(6);
    private static readonly TimeSpan StartupDelay = TimeSpan.FromMinutes(1);

    public SubscriptionOverdueBackgroundService(
        IServiceScopeFactory scopeFactory,
        ILogger<SubscriptionOverdueBackgroundService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Delay(StartupDelay, stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var notifier = scope.ServiceProvider.GetRequiredService<ISubscriptionOverdueNotifier>();
                await notifier.ProcessOverdueClinicsAsync(stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.LogError(ex, "Subscription overdue check failed.");
            }

            try
            {
                await Task.Delay(Interval, stoppingToken);
            }
            catch (TaskCanceledException)
            {
                break;
            }
        }
    }
}
