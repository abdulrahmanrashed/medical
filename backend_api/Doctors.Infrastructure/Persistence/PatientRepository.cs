using Doctors.Application.Common.Interfaces;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Persistence;

public class PatientRepository : IPatientRepository
{
    private readonly ApplicationDbContext _db;

    public PatientRepository(ApplicationDbContext db)
    {
        _db = db;
    }

    public Task<Patient?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        _db.Patients.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

    public Task<Patient?> GetByNormalizedPhoneAsync(string normalizedPhone, CancellationToken cancellationToken = default) =>
        _db.Patients.FirstOrDefaultAsync(p => p.PhoneNumber == normalizedPhone, cancellationToken);

    public IQueryable<Patient> Query() => _db.Patients.AsQueryable();

    public async Task AddAsync(Patient entity, CancellationToken cancellationToken = default) =>
        await _db.Patients.AddAsync(entity, cancellationToken);

    public void Update(Patient entity) => _db.Patients.Update(entity);
}
