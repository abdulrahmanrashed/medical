using Doctors.Domain.Common;
using Doctors.Domain.Entities;
using Doctors.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Doctors.Infrastructure.Persistence;

public class ApplicationDbContext : IdentityDbContext<ApplicationUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<Clinic> Clinics => Set<Clinic>();
    public DbSet<ClinicInvoice> ClinicInvoices => Set<ClinicInvoice>();
    public DbSet<Doctor> Doctors => Set<Doctor>();
    public DbSet<DoctorWorkSchedule> DoctorWorkSchedules => Set<DoctorWorkSchedule>();
    public DbSet<Patient> Patients => Set<Patient>();
    public DbSet<PatientClinic> PatientClinics => Set<PatientClinic>();
    public DbSet<Appointment> Appointments => Set<Appointment>();
    public DbSet<MedicalRecord> MedicalRecords => Set<MedicalRecord>();
    public DbSet<Prescription> Prescriptions => Set<Prescription>();
    public DbSet<Medication> Medications => Set<Medication>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<FileAttachment> FileAttachments => Set<FileAttachment>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<PatientClinic>()
            .HasIndex(pc => new { pc.PatientId, pc.ClinicId })
            .IsUnique();

        builder.Entity<Doctor>()
            .HasIndex(d => d.UserId)
            .IsUnique();

        builder.Entity<Patient>(e =>
        {
            e.HasKey(p => p.Id);
            e.HasIndex(p => p.PhoneNumber).IsUnique();
            e.HasIndex(p => p.Email)
                .IsUnique()
                .HasFilter("[Email] IS NOT NULL");
            e.HasIndex(p => p.UserId)
                .IsUnique()
                .HasFilter("[UserId] IS NOT NULL");
            e.Property(p => p.RegistrationStatus)
                .HasMaxLength(20)
                .HasConversion(
                    v => v.ToStoredValue(),
                    v => string.Equals(v, "DRAFT", StringComparison.OrdinalIgnoreCase)
                        ? PatientRegistrationStatus.Draft
                        : PatientRegistrationStatus.Completed);
        });

        builder.Entity<Appointment>()
            .HasOne(a => a.Patient)
            .WithMany(p => p.Appointments)
            .HasForeignKey(a => a.PatientId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Appointment>()
            .HasOne(a => a.Clinic)
            .WithMany()
            .HasForeignKey(a => a.ClinicId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Appointment>()
            .HasOne(a => a.Doctor)
            .WithMany(d => d.Appointments)
            .HasForeignKey(a => a.DoctorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<MedicalRecord>()
            .HasOne(r => r.Patient)
            .WithMany(p => p.MedicalRecords)
            .HasForeignKey(r => r.PatientId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<MedicalRecord>()
            .HasOne(r => r.Doctor)
            .WithMany(d => d.MedicalRecords)
            .HasForeignKey(r => r.DoctorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<MedicalRecord>()
            .HasOne(r => r.Clinic)
            .WithMany()
            .HasForeignKey(r => r.ClinicId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Prescription>()
            .HasOne(p => p.MedicalRecord)
            .WithMany(r => r.Prescriptions)
            .HasForeignKey(p => p.MedicalRecordId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<Prescription>()
            .HasOne(p => p.Doctor)
            .WithMany(d => d.Prescriptions)
            .HasForeignKey(p => p.DoctorId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<Medication>()
            .HasOne(m => m.Prescription)
            .WithMany(p => p.Medications)
            .HasForeignKey(m => m.PrescriptionId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<FileAttachment>()
            .HasOne(f => f.MedicalRecord)
            .WithMany(r => r.Attachments)
            .HasForeignKey(f => f.MedicalRecordId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<Doctor>()
            .HasOne(d => d.Clinic)
            .WithMany(c => c.Doctors)
            .HasForeignKey(d => d.ClinicId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Entity<DoctorWorkSchedule>(e =>
        {
            e.HasIndex(s => new { s.DoctorId, s.ShiftDate }).IsUnique();
            e.HasOne(s => s.Doctor)
                .WithMany(d => d.WorkSchedules)
                .HasForeignKey(s => s.DoctorId)
                .OnDelete(DeleteBehavior.Cascade);
            e.Property(s => s.ShiftDate).HasColumnType("date");
            e.Property(s => s.StartTime).HasColumnType("time");
            e.Property(s => s.EndTime).HasColumnType("time");
        });

        builder.Entity<Clinic>(e =>
        {
            e.Property(c => c.PaymentStatus).HasConversion<int>();
            e.Property(c => c.TotalAmount).HasPrecision(18, 2);
            e.Property(c => c.PaidAmount).HasPrecision(18, 2);
            e.Property(c => c.RemainingAmount).HasPrecision(18, 2);
        });

        builder.Entity<ClinicInvoice>(e =>
        {
            e.Property(i => i.AmountPaid).HasPrecision(18, 2);
            e.HasOne(i => i.Clinic)
                .WithMany(c => c.Invoices)
                .HasForeignKey(i => i.ClinicId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<PatientClinic>()
            .HasOne(pc => pc.Patient)
            .WithMany(p => p.PatientClinics)
            .HasForeignKey(pc => pc.PatientId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Entity<PatientClinic>()
            .HasOne(pc => pc.Clinic)
            .WithMany(c => c.PatientClinics)
            .HasForeignKey(pc => pc.ClinicId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
