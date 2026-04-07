using AutoMapper;
using Doctors.Application.Common.Exceptions;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Notifications;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Application.Services;

public class NotificationService : INotificationService
{
    private readonly IRepository<Notification> _notifications;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUserService _currentUser;
    private readonly IMapper _mapper;

    public NotificationService(
        IRepository<Notification> notifications,
        IUnitOfWork unitOfWork,
        ICurrentUserService currentUser,
        IMapper mapper)
    {
        _notifications = notifications;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _mapper = mapper;
    }

    public async Task<IReadOnlyList<NotificationDto>> GetMineAsync(CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId ?? throw new ForbiddenException("User is not authenticated.");
        var list = await _notifications.Query()
            .Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        return _mapper.Map<IReadOnlyList<NotificationDto>>(list);
    }

    public async Task MarkReadAsync(int id, CancellationToken cancellationToken = default)
    {
        var userId = _currentUser.UserId ?? throw new ForbiddenException("User is not authenticated.");
        var n = await _notifications.GetByIdAsync(id, cancellationToken);
        if (n is null || n.UserId != userId)
            throw new NotFoundException($"Notification {id} was not found.");
        n.IsRead = true;
        n.UpdatedAtUtc = DateTime.UtcNow;
        _notifications.Update(n);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }

    public async Task NotifyAsync(CreateNotificationDto dto, CancellationToken cancellationToken = default)
    {
        var entity = new Notification
        {
            UserId = dto.UserId,
            Title = dto.Title,
            Message = dto.Message,
            Type = dto.Type,
            IsRead = false,
            RelatedAppointmentId = dto.RelatedAppointmentId,
            RelatedPrescriptionId = dto.RelatedPrescriptionId,
            CreatedAtUtc = DateTime.UtcNow
        };
        await _notifications.AddAsync(entity, cancellationToken);
        await _unitOfWork.SaveChangesAsync(cancellationToken);
    }
}
