namespace Doctors.Domain.Entities;

public class Medication : BaseEntity
{
    public int PrescriptionId { get; set; }
    public Prescription Prescription { get; set; } = null!;
    public string Name { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public string Schedule { get; set; } = string.Empty;
    public string? Instructions { get; set; }
}
