using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Notifications;
using Doctors.Domain.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Doctors.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = $"{AppRoles.Admin},{AppRoles.Doctor},{AppRoles.Reception},{AppRoles.Patient}")]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _notifications;

    public NotificationsController(INotificationService notifications)
    {
        _notifications = notifications;
    }

    [HttpGet("me")]
    public async Task<ActionResult<IReadOnlyList<NotificationDto>>> GetMine(CancellationToken cancellationToken)
    {
        return Ok(await _notifications.GetMineAsync(cancellationToken));
    }

    [HttpPost("{id:int}/read")]
    public async Task<IActionResult> MarkRead(int id, CancellationToken cancellationToken)
    {
        await _notifications.MarkReadAsync(id, cancellationToken);
        return NoContent();
    }
}
