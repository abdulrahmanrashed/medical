using System.Net;
using System.Security.Claims;
using Doctors.Domain.Common;
using Doctors.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Doctors.API.Middleware;

/// <summary>
/// Blocks authenticated Doctor and Reception JWTs when their clinic is unpaid (in addition to login-time check).
/// </summary>
public class ClinicSuspensionMiddleware
{
    private readonly RequestDelegate _next;
    private const string SuspendedJson =
        """{"error":"Account Suspended. Please contact your clinic administrator regarding payment.","status":403}""";

    public ClinicSuspensionMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, ApplicationDbContext db)
    {
        if (context.User?.Identity?.IsAuthenticated == true)
        {
            var skipCheck = context.User.IsInRole(AppRoles.Admin)
                || context.User.IsInRole(AppRoles.Patient)
                || context.User.IsInRole(AppRoles.ClinicAdmin);

            if (!skipCheck)
            {
                if (context.User.IsInRole(AppRoles.Doctor))
                {
                    var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
                    if (!string.IsNullOrWhiteSpace(userId))
                    {
                        var doctor = await db.Doctors.AsNoTracking()
                            .Include(d => d.Clinic)
                            .FirstOrDefaultAsync(d => d.UserId == userId, context.RequestAborted);
                        if (doctor?.Clinic is { PaymentStatus: ClinicPaymentStatus.Unpaid })
                        {
                            await WriteForbiddenAsync(context);
                            return;
                        }
                    }
                }
                else if (context.User.IsInRole(AppRoles.Reception))
                {
                    var userId = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
                    if (!string.IsNullOrWhiteSpace(userId))
                    {
                        var user = await db.Users.AsNoTracking()
                            .FirstOrDefaultAsync(u => u.Id == userId, context.RequestAborted);
                        if (user?.AssignedClinicId is int cid)
                        {
                            var clinic = await db.Clinics.AsNoTracking()
                                .FirstOrDefaultAsync(c => c.Id == cid, context.RequestAborted);
                            if (clinic?.PaymentStatus == ClinicPaymentStatus.Unpaid)
                            {
                                await WriteForbiddenAsync(context);
                                return;
                            }
                        }
                    }
                }
            }
        }

        await _next(context);
    }

    private static Task WriteForbiddenAsync(HttpContext context)
    {
        context.Response.StatusCode = (int)HttpStatusCode.Forbidden;
        context.Response.ContentType = "application/json";
        return context.Response.WriteAsync(SuspendedJson);
    }
}
