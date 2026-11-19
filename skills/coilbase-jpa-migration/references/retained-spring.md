# Keep Spring and migrate a persistence slice

When Spring Boot still owns the web application and datasource, add
`xyz.pvrlabs:coilbase-core:0.1.0-preview5` from the
[PVR Labs Maven repository](https://pvrlabs.github.io/maven/) for this example.
Preview 5 Core declares Jdbi Core 3.55.0. Check the resolved dependencies if
the application manages them separately. The migration guide at the Preview 5
tag uses Preview 4 examples. Verify APIs against the selected release's sources.
[Preview 5 source JAR](https://pvrlabs.github.io/maven/xyz/pvrlabs/coilbase-core/0.1.0-preview5/coilbase-core-0.1.0-preview5-sources.jar)

~~~java
import javax.sql.DataSource;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import pvrlabs.coilbase.RepositoryContext;
import pvrlabs.coilbase.SqlStatement;

@Configuration(proxyBeanMethods = false)
class SliceConfiguration {
    @Bean
    RepositoryContext sliceDatabase(DataSource dataSource) {
        return RepositoryContext.create(dataSource);
    }

    @Bean
    AppointmentStore appointmentStore(RepositoryContext db) {
        return new AppointmentStore(db);
    }

    @Bean
    ConfirmAppointment confirmAppointment(RepositoryContext db, AppointmentStore store) {
        return new ConfirmAppointment(db, store);
    }
}

record ConfirmAppointment(RepositoryContext db, AppointmentStore store) {
    void confirm(int id) {
        db.transactional(() -> store.confirm(id));
    }
}

record AppointmentStore(RepositoryContext db) {
    private static final SqlStatement CONFIRM = SqlStatement.of(
        "update appointments set confirmed = true where id = :id and confirmed = false");

    void confirm(int id) {
        int changed = db.update(CONFIRM, update -> update.bind("id", id).execute());
        if (changed != 1) {
            throw new IllegalStateException("Appointment missing or already confirmed: " + id);
        }
    }
}
~~~

- Leave pool lifecycle and configured schema initialization with Spring Boot.
  Keep retained JPA on its existing transaction manager. Inject the same CoilBase
  context into the migrated service and stores. Sharing a datasource alone
  provides no atomicity across Spring/JPA and Jdbi transactions.
- Explicit store beans omit Spring's `@Repository` exception translation advice.
  If callers depend on translated constraint errors, map those cases
  deliberately and test through the actual Spring wiring. A repository proxy
  can wrap exceptions the controller or service expects to catch.
- Verify affected-row counts for writes that can miss their target. Exercise
  caller-supplied sorting before pagination where the old repository exposed
  it. Map supported sort properties to fixed SQL columns.
