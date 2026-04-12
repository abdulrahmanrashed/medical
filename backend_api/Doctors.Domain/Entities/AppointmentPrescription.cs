namespace Doctors.Domain.Entities;

/// <summary>
/// One medication line tied to a visit (appointment), used for patient-facing schedules and reminders.
/// </summary>
public class AppointmentPrescription : BaseEntity
{
    public int AppointmentId { get; set; }
    public Appointment Appointment { get; set; } = null!;

    public string MedicationName { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;

    /// <summary>How many doses per 24-hour period (e.g. 3 → about every 8 hours).</summary>
    public int TimesPerDay { get; set; } = 1;

    public DateTime StartDateUtc { get; set; }
    public DateTime? EndDateUtc { get; set; }
}
