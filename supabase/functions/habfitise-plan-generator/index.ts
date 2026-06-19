import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const goal = body.goal ?? "improve_fitness";

    const workout =
      goal === "lose_weight"
        ? {
            name: "Fat Loss Circuit",
            durationMinutes: 45,
            muscleGroups: "Full Body · Cardio",
            exercises: [
              { name: "Treadmill intervals", sets: 4 },
              { name: "Goblet squat", sets: 3 },
              { name: "Push-ups", sets: 3 },
              { name: "Row machine", sets: 3 },
            ],
          }
        : goal === "build_muscle"
          ? {
              name: "Upper Body Push",
              durationMinutes: 45,
              muscleGroups: "Chest · Shoulders · Triceps",
              exercises: [
                { name: "Bench press", sets: 4 },
                { name: "Incline DB press", sets: 3 },
                { name: "Cable fly", sets: 3 },
                { name: "Tricep pushdown", sets: 3 },
              ],
            }
          : {
              name: "Full Body Strength",
              durationMinutes: 45,
              muscleGroups: "Full Body",
              exercises: [
                { name: "Barbell squat", sets: 4 },
                { name: "Romanian deadlift", sets: 3 },
                { name: "Overhead press", sets: 3 },
                { name: "Plank", sets: 3 },
              ],
            };

    const plan = {
      ...workout,
      title: workout.name,
      focus: workout.muscleGroups,
      exerciseCount: workout.exercises.length,
      goal,
      trainingDays: body.trainingDays ?? [],
      equipment: body.equipment ?? "gym",
    };

    return new Response(
      JSON.stringify({
        planId: crypto.randomUUID(),
        plan: JSON.stringify(plan),
        generatedAt: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
