namespace Doctors.Application.Common.Exceptions;

public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message) { }
}

public class ForbiddenException : Exception
{
    public ForbiddenException(string message) : base(message) { }
}

public class BadRequestAppException : Exception
{
    public BadRequestAppException(string message) : base(message) { }
}
