namespace Doctors.Application.DTOs.Appointments;

/// <summary>SignalR payload: upsert (full row) or delete (id only).</summary>
public class AppointmentChangePayloadDto
{
    public bool Deleted { get; set; }
    public int? Id { get; set; }
    public int? ClinicId { get; set; }
    public Guid? PatientId { get; set; }
    public int? DoctorId { get; set; }
    public AppointmentDto? Appointment { get; set; }
}
