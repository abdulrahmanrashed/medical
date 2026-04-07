namespace Doctors.Domain.Entities;

public class PatientClinic : BaseEntity
{
    public Guid PatientId { get; set; }
    public Patient Patient { get; set; } = null!;
    public int ClinicId { get; set; }
    public Clinic Clinic { get; set; } = null!;
    public DateTime LinkedAtUtc { get; set; }
}
