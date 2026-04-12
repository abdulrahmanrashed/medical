using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Appointments;

namespace Doctors.Application.Services;

public class NoOpAppointmentRealtimeNotifier : IAppointmentRealtimeNotifier
{
    public Task NotifyAppointmentUpsertAsync(AppointmentDto fullDto, CancellationToken cancellationToken = default) =>
        Task.CompletedTask;

    public Task NotifyAppointmentDeletedAsync(int id, int clinicId, Guid patientId, int? doctorId, CancellationToken cancellationToken = default) =>
        Task.CompletedTask;
}
