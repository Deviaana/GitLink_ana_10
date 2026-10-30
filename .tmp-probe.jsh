import java.text.*;
String[][] cases = {
 {"50", "123"}, {"50.00", "123"}, {"50.00", "124"}, {"50.00", "126"},
 {"10.05", "123"}, {"10.05", "125"}, {"0.2500", "1.15"}, {"0.2500", "1.24"},
 {"0.025", "1.234"}, {"0.205", "1.234"}
};
for (String[] c : cases) {
  DecimalFormat f = new DecimalFormat(c[0]);
  System.out.println(c[0] + " | " + c[1] + " => " + f.format(Double.parseDouble(c[1])));
}
/exit