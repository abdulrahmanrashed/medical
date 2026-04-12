using Doctors.Domain.Common;

namespace Doctors.Application.DTOs.MedicalFiles;

public class MedicalFileDto
{
    public int Id { get; set; }
    public Guid PatientId { get; set; }
    public int? AppointmentId { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string FileUrl { get; set; } = string.Empty;
    public string? PublicUrl { get; set; }
    public MedicalFileType FileType { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
