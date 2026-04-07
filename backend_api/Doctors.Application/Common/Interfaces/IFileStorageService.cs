namespace Doctors.Application.Common.Interfaces;

public interface IFileStorageService
{
    Task<string> SaveAsync(Stream fileStream, string originalFileName, string contentType, CancellationToken cancellationToken = default);
    void DeleteIfExists(string relativePath);
}
