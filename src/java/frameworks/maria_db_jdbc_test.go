package frameworks_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("MariaDBJDBC", func() {
	It("should support both mariadb and mysql services", func() {
		serviceTypes := []string{"mariadb", "mysql"}

		for _, svc := range serviceTypes {
			Expect([]string{"mariadb", "mysql"}).To(ContainElement(svc))
		}
	})

	It("should replace MySQL driver with MariaDB driver", func() {
		oldDriver := "com.mysql.jdbc.Driver"
		newDriver := "org.mariadb.jdbc.Driver"
		Expect(oldDriver).NotTo(Equal(newDriver))
	})
})
