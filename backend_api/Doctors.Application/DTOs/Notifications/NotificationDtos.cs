using Doctors.Domain.Common;

namespace Doctors.Application.DTOs.Notifications;

public class NotificationDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public NotificationType Type { get; set; }
    public bool IsRead { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public int? RelatedAppointmentId { get; set; }
    public int? RelatedPrescriptionId { get; set; }
}

public class CreateNotificationDto
{
    public string UserId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public NotificationType Type { get; set; }
    public int? RelatedAppointmentId { get; set; }
    public int? RelatedPrescriptionId { get; set; }
}
