using Doctors.Application.DTOs.Notifications;

namespace Doctors.Application.Common.Interfaces;

public interface INotificationService
{
    Task<IReadOnlyList<NotificationDto>> GetMineAsync(CancellationToken cancellationToken = default);
    Task MarkReadAsync(int id, CancellationToken cancellationToken = default);
    Task NotifyAsync(CreateNotificationDto dto, CancellationToken cancellationToken = default);
}
