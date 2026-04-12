using Doctors.Domain.Common;

namespace Doctors.Domain.Entities;

public class Appointment : BaseEntity
{
    public Guid PatientId { get; set; }
    public Patient Patient { get; set; } = null!;
    public int ClinicId { get; set; }
    public Clinic Clinic { get; set; } = null!;
    public int? DoctorId { get; set; }
    public Doctor? Doctor { get; set; }

    public string PatientName { get; set; } = string.Empty;
    public string PhoneNumber { get; set; } = string.Empty;
    public DateTime ScheduledAtUtc { get; set; }
    public AppointmentType Type { get; set; }
    public AppointmentStatus Status { get; set; }
    public string? Notes { get; set; }
    public string? DoctorNotes { get; set; }
    public string? ReceptionNotes { get; set; }

    /// <summary>Optional JSON object with type-specific nullable fields (e.g. weeks, fetalHeartRate, a1cLevel, weightKg).</summary>
    public string? SpecializedDataJson { get; set; }

    /// <summary>Free-text list of lab or imaging tests requested for this visit (before results are uploaded).</summary>
    public string? RequestedTests { get; set; }

    public ICollection<AppointmentPrescription> AppointmentPrescriptions { get; set; } = new List<AppointmentPrescription>();
}
