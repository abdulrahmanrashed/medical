using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Notifications;
using Doctors.Domain.Common;
using Doctors.Infrastructure.Identity;
using Doctors.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Services;

public class SubscriptionOverdueNotifier : ISubscriptionOverdueNotifier
{
    private readonly ApplicationDbContext _db;
    private readonly UserManager<ApplicationUser> _userManager;
    private readonly INotificationService _notifications;

    public SubscriptionOverdueNotifier(
        ApplicationDbContext db,
        UserManager<ApplicationUser> userManager,
        INotificationService notifications)
    {
        _db = db;
        _userManager = userManager;
        _notifications = notifications;
    }

    public async Task ProcessOverdueClinicsAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var clinics = await _db.Clinics
            .AsTracking()
            .Where(c => c.PaymentStatus == ClinicPaymentStatus.Unpaid && c.SubscriptionOverdueNotifiedAtUtc == null)
            .ToListAsync(cancellationToken);

        var admins = await _userManager.GetUsersInRoleAsync(AppRoles.Admin);
        if (admins.Count == 0)
            return;

        foreach (var clinic in clinics)
        {
            if (clinic.GetSubscriptionStatus(now) != ClinicSubscriptionUiStatus.UnpaidOverdue)
                continue;

            clinic.SubscriptionOverdueNotifiedAtUtc = now;
            clinic.UpdatedAtUtc = now;

            foreach (var admin in admins)
            {
                await _notifications.NotifyAsync(new CreateNotificationDto
                {
                    UserId = admin.Id,
                    Title = "Clinic subscription overdue",
                    Message = $"Clinic \"{clinic.Name}\" (ID {clinic.Id}) is unpaid and past the 30-day grace period.",
                    Type = NotificationType.ClinicSubscriptionOverdue
                }, cancellationToken);
            }
        }
    }
}
