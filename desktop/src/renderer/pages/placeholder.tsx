import { Card, CardContent } from "@/components/ui/card";

export function PlaceholderPage({ title, description }: { title: string; description: string }) {
  return (
    <section className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold tracking-normal">{title}</h1>
        <p className="mt-1 text-sm text-muted-foreground">{description}</p>
      </div>
      <Card>
        <CardContent className="text-sm text-muted-foreground">This v0.1 skeleton keeps the surface visible while the safe foundations are built.</CardContent>
      </Card>
    </section>
  );
}
