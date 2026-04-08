using Doctors.Application.Common.Interfaces;
using Doctors.Domain.Common;
using Doctors.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Services;

public class ClinicSubscriptionFreezeService : IClinicSubscriptionFreezeService
{
    private readonly ApplicationDbContext _db;

    public ClinicSubscriptionFreezeService(ApplicationDbContext db)
    {
        _db = db;
    }

    public async Task ApplyAutoFreezeAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        var candidates = await _db.Clinics
            .Where(c =>
                c.SubscriptionEndDate != null
                && c.SubscriptionEndDate < now
                && c.RemainingAmount > 0
                && c.PaymentStatus != ClinicPaymentStatus.Frozen)
            .ToListAsync(cancellationToken);

        foreach (var c in candidates)
        {
            c.PaymentStatus = ClinicPaymentStatus.Frozen;
            c.UpdatedAtUtc = now;
        }

        if (candidates.Count > 0)
            await _db.SaveChangesAsync(cancellationToken);
    }
}
