using Doctors.Domain.Entities;

namespace Doctors.Application.Common.Interfaces;

public interface IPatientRepository
{
    Task<Patient?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<Patient?> GetByNormalizedPhoneAsync(string normalizedPhone, CancellationToken cancellationToken = default);
    IQueryable<Patient> Query();
    Task AddAsync(Patient entity, CancellationToken cancellationToken = default);
    void Update(Patient entity);
}
