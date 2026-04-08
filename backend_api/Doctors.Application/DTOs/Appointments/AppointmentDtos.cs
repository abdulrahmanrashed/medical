using Doctors.Domain.Common;

namespace Doctors.Application.DTOs.Appointments;

public class AppointmentDto
{
    public int Id { get; set; }
    public Guid PatientId { get; set; }
    public int ClinicId { get; set; }
    public string ClinicName { get; set; } = string.Empty;
    public int? DoctorId { get; set; }
    public string? DoctorName { get; set; }
    public string PatientName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public DateTime ScheduledAtUtc { get; set; }
    public AppointmentType Type { get; set; }
    public AppointmentStatus Status { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? UpdatedAtUtc { get; set; }
}

public class CreateAppointmentDto
{
    public Guid PatientId { get; set; }
    public int ClinicId { get; set; }
    public int? DoctorId { get; set; }
    public string PatientName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public DateTime ScheduledAtUtc { get; set; }
    public AppointmentType Type { get; set; }
    public string? Notes { get; set; }
}

public class UpdateAppointmentDto
{
    public int? DoctorId { get; set; }
    public string PatientName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public DateTime ScheduledAtUtc { get; set; }
    public AppointmentType Type { get; set; }
    public AppointmentStatus Status { get; set; }
    public string? Notes { get; set; }
}

/// <summary>Doctor-only status transitions (start session / end session).</summary>
public class DoctorAppointmentStatusDto
{
    public AppointmentStatus Status { get; set; }
}
