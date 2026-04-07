using Doctors.Application.Common.Interfaces;
using Doctors.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Persistence;

public class EfRepository<T> : IRepository<T> where T : BaseEntity
{
    private readonly ApplicationDbContext _db;

    public EfRepository(ApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<T?> GetByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        return await _db.Set<T>().FindAsync([id], cancellationToken);
    }

    public IQueryable<T> Query() => _db.Set<T>().AsQueryable();

    public async Task AddAsync(T entity, CancellationToken cancellationToken = default)
    {
        await _db.Set<T>().AddAsync(entity, cancellationToken);
    }

    public void Update(T entity) => _db.Set<T>().Update(entity);

    public void Remove(T entity) => _db.Set<T>().Remove(entity);
}
