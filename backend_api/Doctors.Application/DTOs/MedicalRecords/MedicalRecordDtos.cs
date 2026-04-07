namespace Doctors.Application.DTOs.MedicalRecords;

public class MedicalRecordDto
{
    public int Id { get; set; }
    public Guid PatientId { get; set; }
    public string PatientName { get; set; } = string.Empty;
    public int DoctorId { get; set; }
    public string DoctorName { get; set; } = string.Empty;
    public int ClinicId { get; set; }
    public string? Symptoms { get; set; }
    public string? Diagnosis { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public IReadOnlyList<PrescriptionSummaryDto> Prescriptions { get; set; } = Array.Empty<PrescriptionSummaryDto>();
    public IReadOnlyList<FileAttachmentDto> Attachments { get; set; } = Array.Empty<FileAttachmentDto>();
}

public class PrescriptionSummaryDto
{
    public int Id { get; set; }
    public Guid PatientId { get; set; }
    public int DoctorId { get; set; }
    public IReadOnlyList<MedicationDto> Medications { get; set; } = Array.Empty<MedicationDto>();
}

public class MedicationDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public string Schedule { get; set; } = string.Empty;
    public string? Instructions { get; set; }
}

public class FileAttachmentDto
{
    public int Id { get; set; }
    public string FilePath { get; set; } = string.Empty;
    public string? PublicUrl { get; set; }
    public string OriginalFileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
}

public class CreateMedicalRecordDto
{
    public Guid PatientId { get; set; }
    public int ClinicId { get; set; }
    /// <summary>Optional; when sent, must match the signed-in doctor (same as JWT doctor id).</summary>
    public int? DoctorId { get; set; }
    public string? Symptoms { get; set; }
    public string? Diagnosis { get; set; }
    public string? Notes { get; set; }
    public IReadOnlyList<CreateMedicationLineDto>? InitialMedications { get; set; }
}

public class CreateMedicationLineDto
{
    public string Name { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public string Schedule { get; set; } = string.Empty;
    public string? Instructions { get; set; }
}

public class AddMedicationDto
{
    public int PrescriptionId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Dosage { get; set; } = string.Empty;
    public string Schedule { get; set; } = string.Empty;
    public string? Instructions { get; set; }
}

public class UpdateMedicalRecordDto
{
    public string? Symptoms { get; set; }
    public string? Diagnosis { get; set; }
    public string? Notes { get; set; }
}
