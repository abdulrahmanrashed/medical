using Doctors.Domain.Common;

namespace Doctors.Domain.Entities;

/// <summary>
/// Patient-uploaded document (e.g. lab results) for requested tests; may link to a specific appointment.
/// </summary>
public class MedicalFile : BaseEntity
{
    public Guid PatientId { get; set; }
    public Patient Patient { get; set; } = null!;

    public int? AppointmentId { get; set; }
    public Appointment? Appointment { get; set; }

    public string FileName { get; set; } = string.Empty;

    /// <summary>Relative path under wwwroot (same pattern as medical record attachments).</summary>
    public string FileUrl { get; set; } = string.Empty;

    public MedicalFileType FileType { get; set; }
}
