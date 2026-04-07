using Microsoft.AspNetCore.Identity;

namespace Doctors.Infrastructure.Identity;

public class ApplicationUser : IdentityUser
{
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public int? AssignedClinicId { get; set; }
}
