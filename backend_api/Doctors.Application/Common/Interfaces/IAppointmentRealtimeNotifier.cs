using Doctors.Application.DTOs.Appointments;

namespace Doctors.Application.Common.Interfaces;

/// <summary>Broadcasts appointment upserts/deletes to SignalR groups (no-op outside API host).</summary>
public interface IAppointmentRealtimeNotifier
{
    Task NotifyAppointmentUpsertAsync(AppointmentDto fullDto, CancellationToken cancellationToken = default);
    Task NotifyAppointmentDeletedAsync(int id, int clinicId, Guid patientId, int? doctorId, CancellationToken cancellationToken = default);
}
