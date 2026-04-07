using Doctors.Domain.Common;

namespace Doctors.Domain.Entities;

public class Notification : BaseEntity
{
    public string UserId { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
    public NotificationType Type { get; set; }
    public bool IsRead { get; set; }
    public int? RelatedAppointmentId { get; set; }
    public int? RelatedPrescriptionId { get; set; }
}
