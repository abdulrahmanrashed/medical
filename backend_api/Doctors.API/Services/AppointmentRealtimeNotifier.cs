using Doctors.API.Hubs;
using Doctors.Application.Common.Interfaces;
using Doctors.Application.DTOs.Appointments;
using Microsoft.AspNetCore.SignalR;

namespace Doctors.API.Services;

public class AppointmentRealtimeNotifier : IAppointmentRealtimeNotifier
{
    private readonly IHubContext<AppointmentsHub> _hubContext;

    public AppointmentRealtimeNotifier(IHubContext<AppointmentsHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public async Task NotifyAppointmentUpsertAsync(AppointmentDto fullDto, CancellationToken cancellationToken = default)
    {
        var reception = new AppointmentChangePayloadDto { Deleted = false, Appointment = Clone(fullDto) };

        var forDoctor = Clone(fullDto);
        forDoctor.ReceptionNotes = null;
        var doctorPayload = new AppointmentChangePayloadDto { Deleted = false, Appointment = forDoctor };

        var forPatient = Clone(fullDto);
        forPatient.ReceptionNotes = null;
        forPatient.DoctorNotes = null;
        var patientPayload = new AppointmentChangePayloadDto { Deleted = false, Appointment = forPatient };

        var cid = fullDto.ClinicId;
        var pid = fullDto.PatientId;

        await _hubContext.Clients.Group(AppointmentsHub.ReceptionGroup(cid))
            .SendAsync("AppointmentChanged", reception, cancellationToken);
        await _hubContext.Clients.Group(AppointmentsHub.DoctorGroup(cid))
            .SendAsync("AppointmentChanged", doctorPayload, cancellationToken);
        await _hubContext.Clients.Group(AppointmentsHub.PatientGroup(pid))
            .SendAsync("AppointmentChanged", patientPayload, cancellationToken);
        await _hubContext.Clients.Group("admin")
            .SendAsync("AppointmentChanged", reception, cancellationToken);
    }

    public async Task NotifyAppointmentDeletedAsync(
        int id,
        int clinicId,
        Guid patientId,
        int? doctorId,
        CancellationToken cancellationToken = default)
    {
        var payload = new AppointmentChangePayloadDto
        {
            Deleted = true,
            Id = id,
            ClinicId = clinicId,
            PatientId = patientId,
            DoctorId = doctorId
        };

        await _hubContext.Clients.Group(AppointmentsHub.ReceptionGroup(clinicId))
            .SendAsync("AppointmentChanged", payload, cancellationToken);
        await _hubContext.Clients.Group(AppointmentsHub.DoctorGroup(clinicId))
            .SendAsync("AppointmentChanged", payload, cancellationToken);
        await _hubContext.Clients.Group(AppointmentsHub.PatientGroup(patientId))
            .SendAsync("AppointmentChanged", payload, cancellationToken);
        await _hubContext.Clients.Group("admin")
            .SendAsync("AppointmentChanged", payload, cancellationToken);
    }

    private static AppointmentDto Clone(AppointmentDto s) => new()
    {
        Id = s.Id,
        PatientId = s.PatientId,
        ClinicId = s.ClinicId,
        ClinicName = s.ClinicName,
        DoctorId = s.DoctorId,
        DoctorName = s.DoctorName,
        PatientName = s.PatientName,
        PhoneNumber = s.PhoneNumber,
        ScheduledAtUtc = s.ScheduledAtUtc,
        Type = s.Type,
        Status = s.Status,
        Notes = s.Notes,
        DoctorNotes = s.DoctorNotes,
        ReceptionNotes = s.ReceptionNotes,
        CreatedAtUtc = s.CreatedAtUtc,
        UpdatedAtUtc = s.UpdatedAtUtc
    };
}
