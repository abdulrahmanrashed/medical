using Doctors.Application.DTOs.MedicalFiles;

namespace Doctors.Application.Common.Interfaces;

public interface IMedicalFileService
{
    Task<MedicalFileDto> UploadForCurrentPatientAsync(
        int? appointmentId,
        Stream fileStream,
        string originalFileName,
        string contentType,
        long fileSizeBytes,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<MedicalFileDto>> GetMineAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<MedicalFileDto>> GetForAppointmentAsync(
        int appointmentId,
        CancellationToken cancellationToken = default);
}
