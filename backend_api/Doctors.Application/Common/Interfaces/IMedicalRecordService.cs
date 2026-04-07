using Doctors.Application.DTOs.MedicalRecords;

namespace Doctors.Application.Common.Interfaces;

public interface IMedicalRecordService
{
    Task<IReadOnlyList<MedicalRecordDto>> GetForCurrentUserAsync(CancellationToken cancellationToken = default);
    Task<MedicalRecordDto> GetByIdAsync(int id, CancellationToken cancellationToken = default);
    Task<MedicalRecordDto> CreateAsync(CreateMedicalRecordDto dto, CancellationToken cancellationToken = default);
    Task<MedicalRecordDto> UpdateAsync(int id, UpdateMedicalRecordDto dto, CancellationToken cancellationToken = default);
    Task<MedicalRecordDto> AddMedicationAsync(AddMedicationDto dto, CancellationToken cancellationToken = default);
    Task<MedicalRecordDto> RemoveMedicationAsync(int medicationId, CancellationToken cancellationToken = default);
    Task<MedicalRecordDto> AddAttachmentAsync(int medicalRecordId, string relativePath, string originalFileName, string contentType, long sizeBytes, CancellationToken cancellationToken = default);
}
